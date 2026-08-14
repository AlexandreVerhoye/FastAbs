import Foundation
import simd

/// A single continuous body surface, built once and then deformed by the pose.
///
/// The avatar used to be an assembly of capsules with a sphere dropped at each
/// joint. However carefully those parts were sized they still read as separate
/// objects — a balloon animal rather than a person — because every junction is
/// a silhouette break the eye picks up immediately.
///
/// So the body is described as a signed distance field: one smooth blend of
/// limb and torso volumes, with organic fillets wherever two volumes meet.
/// That field is polygonised once into a single closed surface, each vertex is
/// bound to the bones nearest it, and animation is then ordinary skinning — the
/// mesh never splits, whatever the pose.
struct BodySculpt: Sendable {
    /// One rigid segment that both shapes the body and drives its skin.
    enum Bone: Int, CaseIterable, Sendable {
        case spine, neck, skull
        case leftUpperArm, leftForearm, rightUpperArm, rightForearm
        case leftThigh, leftShin, rightThigh, rightShin
        case leftFoot, rightFoot
    }

    /// Up to four bones drive each vertex; more adds cost without adding
    /// smoothness on a body this simple.
    static let influenceCount = 4

    let positions: [SIMD3<Float>]
    let normals: [SIMD3<Float>]
    let indices: [UInt32]
    /// Flattened `influenceCount` entries per vertex.
    let boneIndices: [Int]
    let boneWeights: [Float]

    var vertexCount: Int { positions.count }
    var triangleCount: Int { indices.count / 3 }
}

// MARK: - Rest pose

/// The neutral standing pose the surface is sculpted around.
///
/// Skinning quality depends on limbs being well separated at rest, so the arms
/// hang away from the body rather than resting against it. Segment lengths match
/// `SkeletonMetrics` exactly, because skinning assumes bones never stretch.
enum RestPose {
    static let pelvis = SIMD3<Float>(0, 0, 0)
    static let chest = SIMD3<Float>(0, 0.58, 0)
    static let neck = SIMD3<Float>(0, 0.84, 0)
    static let head = SIMD3<Float>(0, 0.97, 0)
    static let leftShoulder = SIMD3<Float>(0.25, 0.58, 0)
    static let rightShoulder = SIMD3<Float>(-0.25, 0.58, 0)
    static let leftElbow = SIMD3<Float>(0.41, 0.24, 0)
    static let rightElbow = SIMD3<Float>(-0.41, 0.24, 0)
    static let leftHand = SIMD3<Float>(0.51, -0.06, 0)
    static let rightHand = SIMD3<Float>(-0.51, -0.06, 0)
    static let leftHip = SIMD3<Float>(0.155, 0, 0)
    static let rightHip = SIMD3<Float>(-0.155, 0, 0)
    static let leftKnee = SIMD3<Float>(0.17, -0.52, 0)
    static let rightKnee = SIMD3<Float>(-0.17, -0.52, 0)
    static let leftAnkle = SIMD3<Float>(0.18, -1.02, 0)
    static let rightAnkle = SIMD3<Float>(-0.18, -1.02, 0)
    /// Toes are derived, never hard-coded: the rest skeleton and the posed one
    /// have to agree bone for bone, or skinning starts from a deformed body.
    static var leftToe: SIMD3<Float> { toe(ankle: leftAnkle, knee: leftKnee, front: SIMD3<Float>(0, 0, 1)) }
    static var rightToe: SIMD3<Float> { toe(ankle: rightAnkle, knee: rightKnee, front: SIMD3<Float>(0, 0, 1)) }

    static let pose = BodyPose(
        head: head, neck: neck, chest: chest, pelvis: pelvis,
        leftShoulder: leftShoulder, rightShoulder: rightShoulder,
        leftElbow: leftElbow, rightElbow: rightElbow,
        leftHand: leftHand, rightHand: rightHand,
        leftHip: leftHip, rightHip: rightHip,
        leftKnee: leftKnee, rightKnee: rightKnee,
        leftAnkle: leftAnkle, rightAnkle: rightAnkle
    )

    /// Start and end of each bone in the rest pose.
    static func segment(_ bone: BodySculpt.Bone) -> (SIMD3<Float>, SIMD3<Float>) {
        switch bone {
        case .spine: (pelvis, chest)
        case .neck: (chest, neck)
        case .skull: (neck, head)
        case .leftUpperArm: (leftShoulder, leftElbow)
        case .leftForearm: (leftElbow, leftHand)
        case .rightUpperArm: (rightShoulder, rightElbow)
        case .rightForearm: (rightElbow, rightHand)
        case .leftThigh: (leftHip, leftKnee)
        case .leftShin: (leftKnee, leftAnkle)
        case .rightThigh: (rightHip, rightKnee)
        case .rightShin: (rightKnee, rightAnkle)
        case .leftFoot: (leftAnkle, leftToe)
        case .rightFoot: (rightAnkle, rightToe)
        }
    }

    /// Start and end of each bone for a posed skeleton.
    static func segment(_ bone: BodySculpt.Bone, in pose: BodyPose) -> (SIMD3<Float>, SIMD3<Float>) {
        switch bone {
        case .spine: (pose.pelvis, pose.chest)
        case .neck: (pose.chest, pose.neck)
        case .skull: (pose.neck, pose.head)
        case .leftUpperArm: (pose.leftShoulder, pose.leftElbow)
        case .leftForearm: (pose.leftElbow, pose.leftHand)
        case .rightUpperArm: (pose.rightShoulder, pose.rightElbow)
        case .rightForearm: (pose.rightElbow, pose.rightHand)
        case .leftThigh: (pose.leftHip, pose.leftKnee)
        case .leftShin: (pose.leftKnee, pose.leftAnkle)
        case .rightThigh: (pose.rightHip, pose.rightKnee)
        case .rightShin: (pose.rightKnee, pose.rightAnkle)
        case .leftFoot: (pose.leftAnkle, toe(ankle: pose.leftAnkle, knee: pose.leftKnee, front: front(of: pose)))
        case .rightFoot: (pose.rightAnkle, toe(ankle: pose.rightAnkle, knee: pose.rightKnee, front: front(of: pose)))
        }
    }

    /// The foot points the way the body faces, square to the shin — lying on
    /// your back your toes point up, in a plank they point at the floor.
    static func toe(ankle: SIMD3<Float>, knee: SIMD3<Float>, front: SIMD3<Float>) -> SIMD3<Float> {
        let shin = normalised(ankle - knee, fallback: SIMD3<Float>(0, -1, 0))
        let forward = normalised(
            front - shin * simd_dot(front, shin),
            fallback: SIMD3<Float>(0, 0, 1)
        )
        return ankle + forward * 0.145 + shin * 0.03
    }

    /// The direction the athlete's chest faces.
    static func front(of pose: BodyPose) -> SIMD3<Float> {
        normalised(
            simd_cross(pose.leftShoulder - pose.rightShoulder, pose.chest - pose.pelvis),
            fallback: SIMD3<Float>(0, 0, 1)
        )
    }

    /// The direction from hips to shoulders.
    static func up(of pose: BodyPose) -> SIMD3<Float> {
        normalised(pose.chest - pose.pelvis, fallback: SIMD3<Float>(0, 1, 0))
    }

    static func normalised(_ vector: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)
        return length > 1e-5 ? vector / length : simd_normalize(fallback)
    }
}

// MARK: - Sculpting

extension BodySculpt {
    /// One volume of the body, blended into all the others.
    private struct Volume {
        let start: SIMD3<Float>
        let end: SIMD3<Float>
        let startRadius: Float
        let endRadius: Float
        /// Squash applied per axis before measuring, which turns a round limb
        /// into a flattened one. A human torso is far deeper than it is thin.
        let squash: SIMD3<Float>

        init(
            _ start: SIMD3<Float>,
            _ end: SIMD3<Float>,
            _ startRadius: Float,
            _ endRadius: Float,
            squash: SIMD3<Float> = SIMD3<Float>(1, 1, 1)
        ) {
            self.start = start
            self.end = end
            self.startRadius = startRadius
            self.endRadius = endRadius
            self.squash = squash
        }
    }

    /// The volumes that make up the athlete, in rest space.
    ///
    /// Radii follow adult proportions: an upper arm is about a third as thick as
    /// it is long. The previous figure ran nearer a half, which is most of why
    /// it looked inflated.
    private static var volumes: [Volume] {
        let flatTorso = SIMD3<Float>(1, 1, 0.62)
        let flatHips = SIMD3<Float>(1, 1, 0.74)

        return [
            // Torso: broad across the chest, drawn in at the waist.
            Volume(SIMD3<Float>(0, 0.02, 0), SIMD3<Float>(0, 0.42, 0), 0.15, 0.163, squash: flatTorso),
            Volume(SIMD3<Float>(0, 0.42, 0), SIMD3<Float>(0, 0.6, 0), 0.163, 0.185, squash: flatTorso),
            Volume(SIMD3<Float>(0, -0.09, 0), SIMD3<Float>(0, 0.06, 0), 0.155, 0.152, squash: flatHips),
            // Shoulder caps give the upper body its width without widening the
            // ribcage itself.
            Volume(RestPose.leftShoulder, RestPose.leftShoulder, 0.088, 0.088),
            Volume(RestPose.rightShoulder, RestPose.rightShoulder, 0.088, 0.088),

            // A neck that starts inside the ribcage and a head only a little
            // wider than it merged the two into one lump; the head is now its
            // own volume sitting on a slimmer, shorter neck.
            Volume(SIMD3<Float>(0, 0.6, 0), SIMD3<Float>(0, 0.85, 0), 0.066, 0.055),
            Volume(SIMD3<Float>(0, 0.945, 0), SIMD3<Float>(0, 0.985, 0), 0.1, 0.1, squash: SIMD3<Float>(1, 0.95, 1.03)),

            Volume(RestPose.leftShoulder, RestPose.leftElbow, 0.077, 0.056),
            Volume(RestPose.leftElbow, RestPose.leftHand, 0.056, 0.044),
            Volume(RestPose.rightShoulder, RestPose.rightElbow, 0.077, 0.056),
            Volume(RestPose.rightElbow, RestPose.rightHand, 0.056, 0.044),
            // Hands: a short paddle rather than a ball on a stick.
            Volume(RestPose.leftHand, RestPose.leftHand + SIMD3<Float>(0.03, -0.08, 0), 0.042, 0.032,
                   squash: SIMD3<Float>(1, 1, 0.6)),
            Volume(RestPose.rightHand, RestPose.rightHand + SIMD3<Float>(-0.03, -0.08, 0), 0.042, 0.032,
                   squash: SIMD3<Float>(1, 1, 0.6)),

            Volume(RestPose.leftHip, RestPose.leftKnee, 0.098, 0.066),
            Volume(RestPose.leftKnee, RestPose.leftAnkle, 0.064, 0.044),
            Volume(RestPose.rightHip, RestPose.rightKnee, 0.098, 0.066),
            Volume(RestPose.rightKnee, RestPose.rightAnkle, 0.064, 0.044),
            Volume(RestPose.leftAnkle, RestPose.leftToe, 0.05, 0.036, squash: SIMD3<Float>(1, 0.8, 1)),
            Volume(RestPose.rightAnkle, RestPose.rightToe, 0.05, 0.036, squash: SIMD3<Float>(1, 0.8, 1))
        ]
    }

    /// How softly volumes merge. Large enough to fill the armpit and the groin,
    /// small enough to keep the waist from disappearing.
    private static let blend: Float = 0.046

    private static func field(at point: SIMD3<Float>, volumes: [Volume]) -> Float {
        var distance = Float.greatestFiniteMagnitude
        for volume in volumes {
            distance = smoothMinimum(distance, self.distance(from: point, to: volume), blend)
        }
        return distance
    }

    private static func distance(from point: SIMD3<Float>, to volume: Volume) -> Float {
        // Measuring in squashed space turns the round primitive into an
        // ellipse; scaling the result back keeps it a usable distance.
        let scale = volume.squash
        let smallest = min(scale.x, min(scale.y, scale.z))
        let p = point / scale
        let a = volume.start / scale
        let b = volume.end / scale
        return roundCone(p, a, b, volume.startRadius, volume.endRadius) * smallest
    }

    /// Signed distance to a cone with spherical caps, after Inigo Quilez.
    static func roundCone(
        _ p: SIMD3<Float>,
        _ a: SIMD3<Float>,
        _ b: SIMD3<Float>,
        _ r1: Float,
        _ r2: Float
    ) -> Float {
        let ba = b - a
        let l2 = simd_dot(ba, ba)
        guard l2 > 1e-9 else { return simd_distance(p, a) - r1 }

        let rr = r1 - r2
        let a2 = l2 - rr * rr
        let il2 = 1 / l2
        let pa = p - a
        let y = simd_dot(pa, ba)
        let z = y - l2
        let crossTerm = pa * l2 - ba * y
        let x2 = simd_dot(crossTerm, crossTerm)
        let y2 = y * y * l2
        let z2 = z * z * l2
        let k = (rr < 0 ? -1 : 1) * rr * rr * x2

        if (z < 0 ? -1 : 1) * a2 * z2 > k {
            return (x2 + z2).squareRoot() * il2 - r2
        }
        if (y < 0 ? -1 : 1) * a2 * y2 < k {
            return (x2 + y2).squareRoot() * il2 - r1
        }
        return ((x2 * a2 * il2).squareRoot() + y * rr) * il2 - r1
    }

    /// Polynomial smooth minimum: the fillet that makes limbs grow out of the
    /// body instead of being stuck onto it.
    static func smoothMinimum(_ a: Float, _ b: Float, _ k: Float) -> Float {
        guard k > 0 else { return min(a, b) }
        let h = min(max(0.5 + 0.5 * (b - a) / k, 0), 1)
        return b * (1 - h) + a * h - k * h * (1 - h)
    }
}

// MARK: - Polygonisation

extension BodySculpt {
    /// Sculpts the body. Expensive enough to be done once per process.
    static func build(resolution: Float = 0.032) -> BodySculpt {
        let volumes = self.volumes
        let lower = SIMD3<Float>(-0.72, -1.19, -0.3)
        let upper = SIMD3<Float>(0.72, 1.16, 0.32)

        let counts = SIMD3<Int>(
            Int(((upper.x - lower.x) / resolution).rounded(.up)) + 1,
            Int(((upper.y - lower.y) / resolution).rounded(.up)) + 1,
            Int(((upper.z - lower.z) / resolution).rounded(.up)) + 1
        )

        func location(_ x: Int, _ y: Int, _ z: Int) -> SIMD3<Float> {
            lower + SIMD3<Float>(Float(x), Float(y), Float(z)) * resolution
        }

        // 1. Sample the field on a regular grid.
        var samples = [Float](repeating: 0, count: counts.x * counts.y * counts.z)
        func sampleIndex(_ x: Int, _ y: Int, _ z: Int) -> Int {
            (z * counts.y + y) * counts.x + x
        }
        for z in 0..<counts.z {
            for y in 0..<counts.y {
                for x in 0..<counts.x {
                    samples[sampleIndex(x, y, z)] = field(at: location(x, y, z), volumes: volumes)
                }
            }
        }

        // 2. Surface nets: one vertex per cell the surface passes through,
        // placed at the average of the crossings on that cell's edges. This
        // gives a smoother, lighter mesh than marching cubes and needs no
        // lookup tables.
        let cells = SIMD3<Int>(counts.x - 1, counts.y - 1, counts.z - 1)
        var cellVertex = [Int32](repeating: -1, count: cells.x * cells.y * cells.z)
        func cellIndex(_ x: Int, _ y: Int, _ z: Int) -> Int {
            (z * cells.y + y) * cells.x + x
        }

        let corners: [SIMD3<Int>] = [
            SIMD3(0, 0, 0), SIMD3(1, 0, 0), SIMD3(0, 1, 0), SIMD3(1, 1, 0),
            SIMD3(0, 0, 1), SIMD3(1, 0, 1), SIMD3(0, 1, 1), SIMD3(1, 1, 1)
        ]
        let cellEdges: [(Int, Int)] = [
            (0, 1), (2, 3), (4, 5), (6, 7),
            (0, 2), (1, 3), (4, 6), (5, 7),
            (0, 4), (1, 5), (2, 6), (3, 7)
        ]

        var positions: [SIMD3<Float>] = []
        positions.reserveCapacity(4_096)

        for z in 0..<cells.z {
            for y in 0..<cells.y {
                for x in 0..<cells.x {
                    var values = [Float](repeating: 0, count: 8)
                    var inside = 0
                    for (slot, corner) in corners.enumerated() {
                        let value = samples[sampleIndex(x + corner.x, y + corner.y, z + corner.z)]
                        values[slot] = value
                        if value < 0 { inside += 1 }
                    }
                    guard inside > 0, inside < 8 else { continue }

                    var sum = SIMD3<Float>.zero
                    var crossings: Float = 0
                    for (a, b) in cellEdges {
                        let valueA = values[a]
                        let valueB = values[b]
                        guard (valueA < 0) != (valueB < 0) else { continue }
                        let t = valueA / (valueA - valueB)
                        let pointA = location(x + corners[a].x, y + corners[a].y, z + corners[a].z)
                        let pointB = location(x + corners[b].x, y + corners[b].y, z + corners[b].z)
                        sum += pointA + (pointB - pointA) * t
                        crossings += 1
                    }
                    guard crossings > 0 else { continue }

                    cellVertex[cellIndex(x, y, z)] = Int32(positions.count)
                    positions.append(sum / crossings)
                }
            }
        }

        // 3. Join neighbouring cells across every grid edge the surface crosses.
        var indices: [UInt32] = []
        indices.reserveCapacity(positions.count * 6)

        func vertex(_ x: Int, _ y: Int, _ z: Int) -> Int32? {
            guard x >= 0, y >= 0, z >= 0, x < cells.x, y < cells.y, z < cells.z else { return nil }
            let index = cellVertex[cellIndex(x, y, z)]
            return index >= 0 ? index : nil
        }

        func emitQuad(_ quad: [Int32], outward: SIMD3<Float>) {
            let a = positions[Int(quad[0])]
            let b = positions[Int(quad[1])]
            let c = positions[Int(quad[2])]
            // Deriving the winding from the geometry keeps every face pointing
            // out without hand-deriving a case per axis.
            let facing = simd_cross(b - a, c - a)
            let ordered = simd_dot(facing, outward) >= 0 ? quad : [quad[0], quad[3], quad[2], quad[1]]
            indices.append(contentsOf: [
                UInt32(ordered[0]), UInt32(ordered[1]), UInt32(ordered[2]),
                UInt32(ordered[0]), UInt32(ordered[2]), UInt32(ordered[3])
            ])
        }

        for z in 0..<counts.z {
            for y in 0..<counts.y {
                for x in 0..<counts.x {
                    let value = samples[sampleIndex(x, y, z)]

                    if x + 1 < counts.x, y >= 1, z >= 1 {
                        let next = samples[sampleIndex(x + 1, y, z)]
                        if (value < 0) != (next < 0),
                           let a = vertex(x, y - 1, z - 1), let b = vertex(x, y, z - 1),
                           let c = vertex(x, y, z), let d = vertex(x, y - 1, z) {
                            emitQuad([a, b, c, d], outward: SIMD3<Float>(value < 0 ? 1 : -1, 0, 0))
                        }
                    }
                    if y + 1 < counts.y, x >= 1, z >= 1 {
                        let next = samples[sampleIndex(x, y + 1, z)]
                        if (value < 0) != (next < 0),
                           let a = vertex(x - 1, y, z - 1), let b = vertex(x, y, z - 1),
                           let c = vertex(x, y, z), let d = vertex(x - 1, y, z) {
                            emitQuad([a, b, c, d], outward: SIMD3<Float>(0, value < 0 ? 1 : -1, 0))
                        }
                    }
                    if z + 1 < counts.z, x >= 1, y >= 1 {
                        let next = samples[sampleIndex(x, y, z + 1)]
                        if (value < 0) != (next < 0),
                           let a = vertex(x - 1, y - 1, z), let b = vertex(x, y - 1, z),
                           let c = vertex(x, y, z), let d = vertex(x - 1, y, z) {
                            emitQuad([a, b, c, d], outward: SIMD3<Float>(0, 0, value < 0 ? 1 : -1))
                        }
                    }
                }
            }
        }

        // 4. Normals straight from the field, which is smoother than anything
        // recovered from the triangles.
        let epsilon = resolution * 0.5
        let normals = positions.map { point -> SIMD3<Float> in
            let gradient = SIMD3<Float>(
                field(at: point + SIMD3<Float>(epsilon, 0, 0), volumes: volumes)
                    - field(at: point - SIMD3<Float>(epsilon, 0, 0), volumes: volumes),
                field(at: point + SIMD3<Float>(0, epsilon, 0), volumes: volumes)
                    - field(at: point - SIMD3<Float>(0, epsilon, 0), volumes: volumes),
                field(at: point + SIMD3<Float>(0, 0, epsilon), volumes: volumes)
                    - field(at: point - SIMD3<Float>(0, 0, epsilon), volumes: volumes)
            )
            let length = simd_length(gradient)
            return length > 1e-6 ? gradient / length : SIMD3<Float>(0, 1, 0)
        }

        let binding = bind(positions: positions)
        return BodySculpt(
            positions: positions,
            normals: normals,
            indices: indices,
            boneIndices: binding.indices,
            boneWeights: binding.weights
        )
    }

    /// Binds each vertex to the bones nearest it.
    ///
    /// Weight falls off steeply with distance so a limb stays rigid along its
    /// length, while still blending across a joint where two bones are equally
    /// close — which is exactly where the skin needs to bend.
    private static func bind(positions: [SIMD3<Float>]) -> (indices: [Int], weights: [Float]) {
        let bones = Bone.allCases
        let segments = bones.map { RestPose.segment($0) }

        var indices = [Int](repeating: 0, count: positions.count * influenceCount)
        var weights = [Float](repeating: 0, count: positions.count * influenceCount)

        for (vertex, point) in positions.enumerated() {
            var scored: [(bone: Int, weight: Float)] = []
            scored.reserveCapacity(bones.count)

            for (bone, segment) in segments.enumerated() {
                let distance = distanceToSegment(point, segment.0, segment.1)
                scored.append((bone, 1 / pow(distance + 0.02, 4)))
            }
            scored.sort { $0.weight > $1.weight }

            let best = scored.prefix(influenceCount)
            let total = best.reduce(0) { $0 + $1.weight }
            for (slot, entry) in best.enumerated() {
                indices[vertex * influenceCount + slot] = entry.bone
                weights[vertex * influenceCount + slot] = total > 0 ? entry.weight / total : 0
            }
        }

        return (indices, weights)
    }

    static func distanceToSegment(
        _ point: SIMD3<Float>,
        _ start: SIMD3<Float>,
        _ end: SIMD3<Float>
    ) -> Float {
        let along = end - start
        let lengthSquared = simd_dot(along, along)
        guard lengthSquared > 1e-9 else { return simd_distance(point, start) }
        let t = min(max(simd_dot(point - start, along) / lengthSquared, 0), 1)
        return simd_distance(point, start + along * t)
    }
}

// MARK: - Skinning

/// Turns a posed skeleton into per-bone transforms and applies them to the skin.
enum BodySkinner {
    /// Rest-to-pose transform for each bone, in `BodySculpt.Bone` order.
    static func transforms(for pose: BodyPose) -> [simd_float4x4] {
        let restFrame = bodyFrame(of: RestPose.pose)
        let poseFrame = bodyFrame(of: pose)

        return BodySculpt.Bone.allCases.map { bone in
            let rest = RestPose.segment(bone)
            let posed = RestPose.segment(bone, in: pose)

            // Each bone gets a full orientation, not just a direction: without a
            // reference across the body the limb's twist would be arbitrary and
            // the skin would spin around the bone as the pose changed.
            let restBasis = basis(along: rest.1 - rest.0, reference: restFrame)
            let poseBasis = basis(along: posed.1 - posed.0, reference: poseFrame)
            let rotation = poseBasis * restBasis.transpose

            var transform = simd_float4x4(
                SIMD4(rotation.columns.0, 0),
                SIMD4(rotation.columns.1, 0),
                SIMD4(rotation.columns.2, 0),
                SIMD4(0, 0, 0, 1)
            )
            let translation = posed.0 - rotation * rest.0
            transform.columns.3 = SIMD4(translation, 1)
            return transform
        }
    }

    /// Deforms the rest surface into the posed one.
    static func apply(
        _ transforms: [simd_float4x4],
        to sculpt: BodySculpt,
        positions: inout [SIMD3<Float>],
        normals: inout [SIMD3<Float>]
    ) {
        let influences = BodySculpt.influenceCount

        for vertex in 0..<sculpt.vertexCount {
            let restPosition = sculpt.positions[vertex]
            let restNormal = sculpt.normals[vertex]
            var position = SIMD3<Float>.zero
            var normal = SIMD3<Float>.zero

            for slot in 0..<influences {
                let weight = sculpt.boneWeights[vertex * influences + slot]
                guard weight > 0 else { continue }
                let transform = transforms[sculpt.boneIndices[vertex * influences + slot]]
                let rotation = simd_float3x3(
                    transform.columns.0.xyz,
                    transform.columns.1.xyz,
                    transform.columns.2.xyz
                )
                position += weight * (rotation * restPosition + transform.columns.3.xyz)
                normal += weight * (rotation * restNormal)
            }

            positions[vertex] = position
            let length = simd_length(normal)
            normals[vertex] = length > 1e-6 ? normal / length : SIMD3<Float>(0, 1, 0)
        }
    }

    /// The body's own axes, used as the twist reference for every bone.
    private struct BodyFrame {
        let front: SIMD3<Float>
        let up: SIMD3<Float>
        var across: SIMD3<Float> { simd_cross(front, up) }
    }

    private static func bodyFrame(of pose: BodyPose) -> BodyFrame {
        BodyFrame(front: RestPose.front(of: pose), up: RestPose.up(of: pose))
    }

    /// Builds a basis whose Y axis runs along the bone.
    ///
    /// Every fallback is expressed in the body's own axes rather than the
    /// world's. A world-space fallback means the rest pose and the posed one can
    /// disagree about which way a limb is rolled — and a limb rolled differently
    /// at each end of the blend shears the skin flat.
    private static func basis(along axis: SIMD3<Float>, reference: BodyFrame) -> simd_float3x3 {
        let length = simd_length(axis)
        let yAxis = length > 1e-6 ? axis / length : reference.up

        var hint = reference.front
        if abs(simd_dot(hint, yAxis)) > 0.95 {
            hint = reference.up
            if abs(simd_dot(hint, yAxis)) > 0.95 {
                hint = reference.across
            }
        }

        let xAxis = simd_normalize(simd_cross(hint, yAxis))
        let zAxis = simd_cross(yAxis, xAxis)
        return simd_float3x3(xAxis, yAxis, zAxis)
    }
}

extension SIMD4 where Scalar == Float {
    var xyz: SIMD3<Float> { SIMD3(x, y, z) }
}

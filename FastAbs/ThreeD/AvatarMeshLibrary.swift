import RealityKit
import simd

/// Shared, low-poly meshes shaped as smooth athletic volumes.
///
/// The previous renderer scaled rounded boxes and exposed a sphere at every
/// joint. These meshes keep a continuous silhouette while remaining light
/// enough to deform procedurally at 60 fps.
@MainActor
enum AvatarMeshLibrary {
    // A capsule's `top` sits at the far end of the bone and `bottom` at the
    // joint it hangs from, so limbs taper outward the way a real one does.
    // The torso is deliberately narrower than the shoulder span: when it was as
    // wide as the shoulders the whole upper body rendered as one bean.
    static let torsoTopRadius: Float = 0.215
    static let torsoBottomRadius: Float = 0.168
    static let torso = taperedCapsule(topRadius: torsoTopRadius, bottomRadius: torsoBottomRadius)
    static let pelvis = taperedCapsule(topRadius: 0.175, bottomRadius: 0.168)
    static let neck = taperedCapsule(topRadius: 0.076, bottomRadius: 0.092)
    static let upperArm = taperedCapsule(topRadius: 0.056, bottomRadius: 0.076)
    static let forearm = taperedCapsule(topRadius: 0.045, bottomRadius: 0.06)
    static let thigh = taperedCapsule(topRadius: 0.078, bottomRadius: 0.102)
    static let shin = taperedCapsule(topRadius: 0.052, bottomRadius: 0.078)
    static let sphere = MeshResource.generateSphere(radius: 1)

    /// A lens-shaped band that wraps the torso, used for one muscle group.
    ///
    /// Muscle groups were previously flat patches pinned in front of the body
    /// at a guessed depth. On a curved torso most of each patch ended up buried
    /// and only the tip of its dome showed, which is why the abdominal map read
    /// as a few red specks. A shell is a slice of the torso's own cylinder, so
    /// it follows the body exactly and stays fully visible however the athlete
    /// turns.
    ///
    /// The mesh is unit-sized: radius 1 in X/Z, height 1 in Y. Placed as a child
    /// of the torso it inherits the torso's own non-uniform scale, so it takes
    /// on the same elliptical cross-section for free.
    static func muscleShell(centerAngle: Float, halfWidth: Float) -> MeshShellHandle {
        MeshShellHandle(resource: buildShell(centerAngle: centerAngle, halfWidth: halfWidth))
    }

    /// Wrapper so callers cannot mistake a shell for an ordinary mesh.
    struct MeshShellHandle {
        let resource: MeshResource
    }

    private static func buildShell(
        centerAngle: Float,
        halfWidth: Float,
        columns: Int = 24,
        rows: Int = 18,
        relief: Float = 0.028
    ) -> MeshResource {
        var positions: [SIMD3<Float>] = []
        var normals: [SIMD3<Float>] = []

        for row in 0...rows {
            let vertical = Float(row) / Float(rows)
            let y = -0.5 + vertical
            // Taper the band toward its top and bottom edges so it reads as a
            // muscle belly rather than a strip of tape.
            let edge = abs(vertical - 0.5) * 2
            // Full width for most of the band, rounding off only at the very
            // ends: a lens-shaped taper made each group look like a fang.
            let taper = pow(max(0, 1 - pow(edge, 7)), 0.32)

            for column in 0...columns {
                let across = Float(column) / Float(columns) * 2 - 1
                let angle = centerAngle + across * halfWidth * taper
                let outward = SIMD3<Float>(sin(angle), 0, cos(angle))
                // Sit just outside the torso, and a touch further at the centre
                // so the group catches light like relief.
                let radius = 1 + relief * taper
                positions.append(SIMD3<Float>(outward.x * radius, y, outward.z * radius))
                normals.append(outward)
            }
        }

        var indices: [UInt32] = []
        let stride = columns + 1
        for row in 0..<rows {
            for column in 0..<columns {
                let a = UInt32(row * stride + column)
                let b = UInt32(row * stride + column + 1)
                let c = UInt32((row + 1) * stride + column + 1)
                let d = UInt32((row + 1) * stride + column)
                // Wound so the face normal points away from the torso: the
                // reverse order renders the shell inside-out, and back-face
                // culling then hides the muscle map completely.
                indices.append(contentsOf: [a, b, c, a, c, d])
            }
        }

        var descriptor = MeshDescriptor(name: "FastAbs muscle shell")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)

        do {
            return try MeshResource.generate(from: [descriptor])
        } catch {
            return .generateSphere(radius: 0.1)
        }
    }

    /// Area-weighted vertex normals, so the patch shades as one smooth surface.
    private static func smoothNormals(
        positions: [SIMD3<Float>],
        indices: [UInt32]
    ) -> [SIMD3<Float>] {
        var normals = [SIMD3<Float>](repeating: .zero, count: positions.count)

        for triangle in stride(from: 0, to: indices.count, by: 3) {
            let a = Int(indices[triangle])
            let b = Int(indices[triangle + 1])
            let c = Int(indices[triangle + 2])
            let face = simd_cross(positions[b] - positions[a], positions[c] - positions[a])
            normals[a] += face
            normals[b] += face
            normals[c] += face
        }

        return normals.map { normal in
            let length = simd_length(normal)
            return length > 0.0001 ? normal / length : SIMD3<Float>(0, 0, 1)
        }
    }

    private static func taperedCapsule(
        topRadius: Float,
        bottomRadius: Float,
        radialSegments: Int = 20,
        capSegments: Int = 5
    ) -> MeshResource {
        struct Ring {
            let y: Float
            let radius: Float
            let normalY: Float
            let normalRadius: Float
        }

        let bottomCenter = -0.5 + bottomRadius
        let topCenter = 0.5 - topRadius
        var rings: [Ring] = []

        for index in 1...capSegments {
            let progress = Float(index) / Float(capSegments)
            let angle = -Float.pi / 2 + progress * Float.pi / 2
            rings.append(
                Ring(
                    y: bottomCenter + sin(angle) * bottomRadius,
                    radius: cos(angle) * bottomRadius,
                    normalY: sin(angle),
                    normalRadius: cos(angle)
                )
            )
        }

        for index in 0..<capSegments {
            let progress = Float(index) / Float(capSegments)
            let angle = progress * Float.pi / 2
            rings.append(
                Ring(
                    y: topCenter + sin(angle) * topRadius,
                    radius: cos(angle) * topRadius,
                    normalY: sin(angle),
                    normalRadius: cos(angle)
                )
            )
        }

        var positions: [SIMD3<Float>] = [SIMD3<Float>(0, -0.5, 0)]
        var normals: [SIMD3<Float>] = [SIMD3<Float>(0, -1, 0)]

        for ring in rings {
            for segment in 0..<radialSegments {
                let angle = Float(segment) / Float(radialSegments) * 2 * .pi
                let radial = SIMD2<Float>(cos(angle), sin(angle))
                positions.append(
                    SIMD3<Float>(
                        radial.x * ring.radius,
                        ring.y,
                        radial.y * ring.radius
                    )
                )
                normals.append(
                    simd_normalize(
                        SIMD3<Float>(
                            radial.x * ring.normalRadius,
                            ring.normalY,
                            radial.y * ring.normalRadius
                        )
                    )
                )
            }
        }

        let topPole = UInt32(positions.count)
        positions.append(SIMD3<Float>(0, 0.5, 0))
        normals.append(SIMD3<Float>(0, 1, 0))

        var indices: [UInt32] = []
        let firstRing = 1
        for segment in 0..<radialSegments {
            let next = (segment + 1) % radialSegments
            indices.append(contentsOf: [
                0,
                UInt32(firstRing + next),
                UInt32(firstRing + segment)
            ])
        }

        for ringIndex in 0..<(rings.count - 1) {
            let lower = firstRing + ringIndex * radialSegments
            let upper = lower + radialSegments
            for segment in 0..<radialSegments {
                let next = (segment + 1) % radialSegments
                let a = UInt32(lower + segment)
                let b = UInt32(lower + next)
                let c = UInt32(upper + next)
                let d = UInt32(upper + segment)
                indices.append(contentsOf: [a, d, b, b, d, c])
            }
        }

        let lastRing = firstRing + (rings.count - 1) * radialSegments
        for segment in 0..<radialSegments {
            let next = (segment + 1) % radialSegments
            indices.append(contentsOf: [
                UInt32(lastRing + segment),
                topPole,
                UInt32(lastRing + next)
            ])
        }

        var descriptor = MeshDescriptor(name: "FastAbs athletic volume")
        descriptor.positions = MeshBuffers.Positions(positions)
        descriptor.normals = MeshBuffers.Normals(normals)
        descriptor.primitives = .triangles(indices)

        do {
            return try MeshResource.generate(from: [descriptor])
        } catch {
            return .generateBox(size: 1, cornerRadius: 0.48)
        }
    }
}

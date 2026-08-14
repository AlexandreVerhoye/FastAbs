import Foundation
import Testing
import simd
@testable import FastAbs

/// The body is one closed surface deformed by skinning. These tests hold the
/// properties that make that surface usable: it exists, it is watertight, it
/// stays the right size, and skinning neither tears it nor collapses it.
@Suite("Body sculpt")
struct BodySculptTests {
    static let sculpt = BodySculpt.build()

    @Test("The sculpt produces a usable mesh")
    func meshIsBuilt() {
        let sculpt = Self.sculpt

        #expect(sculpt.vertexCount > 1_500, "only \(sculpt.vertexCount) vertices — too coarse for smooth limbs")
        #expect(sculpt.vertexCount < 20_000, "\(sculpt.vertexCount) vertices is too heavy to skin every frame")
        #expect(sculpt.triangleCount > 0)
        #expect(sculpt.indices.count % 3 == 0)
        #expect(sculpt.indices.allSatisfy { $0 < UInt32(sculpt.vertexCount) }, "an index points past the vertices")
    }

    @Test("Every vertex and normal is valid")
    func meshIsNumericallySound() {
        for position in Self.sculpt.positions {
            #expect(position.x.isFinite && position.y.isFinite && position.z.isFinite)
        }
        for normal in Self.sculpt.normals {
            #expect(abs(simd_length(normal) - 1) < 0.01, "normal is not unit length")
        }
    }

    @Test("The surface is watertight")
    func meshIsClosed() {
        // Every edge of a closed surface is shared by exactly two triangles. A
        // hole shows up on screen as a dark speck where the inside shows
        // through, which is what a naive polygonisation tends to leave behind.
        var edgeUse: [Int64: Int] = [:]
        edgeUse.reserveCapacity(Self.sculpt.indices.count)

        for triangle in stride(from: 0, to: Self.sculpt.indices.count, by: 3) {
            let corners = [
                Self.sculpt.indices[triangle],
                Self.sculpt.indices[triangle + 1],
                Self.sculpt.indices[triangle + 2]
            ]
            for slot in 0..<3 {
                let a = corners[slot]
                let b = corners[(slot + 1) % 3]
                let key = Int64(min(a, b)) << 32 | Int64(max(a, b))
                edgeUse[key, default: 0] += 1
            }
        }

        let openEdges = edgeUse.values.count { $0 != 2 }
        #expect(openEdges == 0, "\(openEdges) edges are not shared by exactly two triangles")
    }

    @Test("The athlete is the size the scene expects")
    func meshFillsTheRestPose() {
        let xs = Self.sculpt.positions.map(\.x)
        let ys = Self.sculpt.positions.map(\.y)
        let zs = Self.sculpt.positions.map(\.z)

        // Head crown down to the soles, and shoulder to shoulder.
        #expect((ys.max() ?? 0) > 1.05 && (ys.max() ?? 0) < 1.2, "the crown sits at \(ys.max() ?? 0)")
        #expect((ys.min() ?? 0) < -1.03 && (ys.min() ?? 0) > -1.15, "the soles sit at \(ys.min() ?? 0)")
        #expect((xs.max() ?? 0) > 0.5, "the athlete is too narrow")
        #expect((zs.max() ?? 0) < 0.35, "the athlete is too deep to read as a person")
    }

    @Test("Limbs are round, not flattened blades")
    func limbsHaveVolume() {
        // A grid too coarse for a thin limb turns it into a wedge. Comparing the
        // spread across the limb in both directions catches that directly.
        let forearm = Self.sculpt.positions.filter {
            $0.x > 0.42 && $0.x < 0.5 && $0.y > -0.02 && $0.y < 0.2
        }
        #expect(forearm.count > 20, "the forearm barely has any surface")

        let depth = (forearm.map(\.z).max() ?? 0) - (forearm.map(\.z).min() ?? 0)
        #expect(depth > 0.06, "the forearm is only \(depth) deep — it is a blade, not a limb")
    }

    @Test("Skinning the rest pose changes nothing")
    func restPoseIsIdentity() {
        // The rest pose must map to itself, or every other pose inherits the
        // same error.
        var positions = Self.sculpt.positions
        var normals = Self.sculpt.normals
        let transforms = BodySkinner.transforms(for: RestPose.pose)
        BodySkinner.apply(transforms, to: Self.sculpt, positions: &positions, normals: &normals)

        var worst: Float = 0
        for (original, skinned) in zip(Self.sculpt.positions, positions) {
            worst = max(worst, simd_distance(original, skinned))
        }
        #expect(worst < 0.002, "the rest pose drifts by \(worst)")
    }

    @Test("Skinning any exercise pose keeps the body intact")
    func skinningPreservesTheBody() {
        var positions = Self.sculpt.positions
        var normals = Self.sculpt.normals

        for motion in MotionSystemTests.allMotions {
            for phase in [Float(0), 0.25, 0.5, 0.75] {
                let pose = MotionLibrary.pose(for: motion, phase: phase)
                let transforms = BodySkinner.transforms(for: pose)
                BodySkinner.apply(transforms, to: Self.sculpt, positions: &positions, normals: &normals)

                for position in positions {
                    #expect(
                        position.x.isFinite && position.y.isFinite && position.z.isFinite,
                        "\(motion.rawValue) at \(phase) produced an invalid vertex"
                    )
                }
                for normal in normals {
                    #expect(
                        abs(simd_length(normal) - 1) < 0.05,
                        "\(motion.rawValue) at \(phase) produced a degenerate normal"
                    )
                }
            }
        }
    }

    @Test("The skin follows the skeleton it is bound to")
    func skinTracksTheSkeleton() {
        var positions = Self.sculpt.positions
        var normals = Self.sculpt.normals

        for motion in [MotionKind.crunch, .plank, .bicycle, .vSit] {
            let pose = MotionLibrary.pose(for: motion, phase: 0.4)
            let transforms = BodySkinner.transforms(for: pose)
            BodySkinner.apply(transforms, to: Self.sculpt, positions: &positions, normals: &normals)

            // Every joint should end up inside the surface bound to it, which is
            // the cheapest way to catch skin that has drifted off its skeleton.
            for joint in pose.joints {
                let nearest = positions.map { simd_distance($0, joint) }.min() ?? .greatestFiniteMagnitude
                #expect(
                    nearest < 0.3,
                    "\(motion.rawValue): the skin is \(nearest) away from a joint"
                )
            }
        }
    }

    @Test("Bone weights are a proper blend")
    func weightsAreNormalised() {
        let influences = BodySculpt.influenceCount

        for vertex in 0..<Self.sculpt.vertexCount {
            var total: Float = 0
            for slot in 0..<influences {
                let weight = Self.sculpt.boneWeights[vertex * influences + slot]
                #expect(weight >= 0 && weight <= 1, "weight \(weight) is out of range")
                total += weight

                let bone = Self.sculpt.boneIndices[vertex * influences + slot]
                #expect(bone >= 0 && bone < BodySculpt.Bone.allCases.count, "bone \(bone) does not exist")
            }
            #expect(abs(total - 1) < 0.001, "weights sum to \(total)")
        }
    }

    @Test("The distance field blends volumes instead of stacking them")
    func smoothMinimumFillets() {
        // A hard minimum leaves a crease where two volumes meet; the smooth one
        // has to dip below both to round the junction off.
        let hard = min(Float(0.1), Float(0.1))
        let soft = BodySculpt.smoothMinimum(0.1, 0.1, 0.055)

        #expect(soft < hard, "the blend adds no fillet at all")
        #expect(soft > hard - 0.055, "the blend swallows the shape")
        #expect(BodySculpt.smoothMinimum(0.1, 5, 0.055) > 0.09, "a distant volume should barely matter")
        #expect(BodySculpt.smoothMinimum(-0.2, 0.4, 0) == -0.2, "a zero blend is a plain minimum")
    }
}

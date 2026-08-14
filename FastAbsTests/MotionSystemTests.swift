import Foundation
import Testing
import simd
@testable import FastAbs

/// Everything the animation must guarantee frame after frame.
///
/// These are the invariants that separate a body from a puppet: bones that keep
/// their length, joints that never jump, and a figure that stays on the mat.
@Suite("Motion system")
struct MotionSystemTests {
    static let allMotions: [MotionKind] = {
        Array(Set(ExerciseCatalog.all.map(\.motion)).union([.rest]))
            .sorted { $0.rawValue < $1.rawValue }
    }()

    static let sampleCount = 96
    static let phases: [Float] = (0..<sampleCount).map { Float($0) / Float(sampleCount) }

    @Test("Every motion covers the whole catalog")
    func catalogMotionsAreAllChoreographed() {
        // A motion missing from the library would silently fall back to a pose
        // that has nothing to do with the exercise being demonstrated.
        for motion in Self.allMotions {
            let metadata = MotionLibrary.metadata(for: motion)
            #expect(!metadata.title.isEmpty, "\(motion.rawValue) has no title")
            #expect(
                !metadata.accessibilityDescription.isEmpty,
                "\(motion.rawValue) has no accessibility description"
            )
            #expect(metadata.cyclesPerSecond > 0, "\(motion.rawValue) never advances")
            #expect(metadata.cyclesPerSecond < 1.5, "\(motion.rawValue) is unrealistically fast")
        }
    }

    @Test("Bones never change length during a movement")
    func bonesStayRigid() {
        let metrics = SkeletonMetrics.standard

        for motion in Self.allMotions {
            for phase in Self.phases {
                let pose = MotionLibrary.pose(for: motion, phase: phase)
                for bone in BodyPose.bones {
                    let expected = metrics[keyPath: bone.length]
                    let actual = pose.length(of: bone)
                    #expect(
                        abs(actual - expected) < 0.001,
                        """
                        \(motion.rawValue) at phase \(phase): \(bone.name) measured \(actual), \
                        expected \(expected)
                        """
                    )
                }
            }
        }
    }

    @Test("No joint ever produces an invalid coordinate")
    func posesStayNumericallyValid() {
        for motion in Self.allMotions {
            for phase in Self.phases {
                let pose = MotionLibrary.pose(for: motion, phase: phase)
                for joint in pose.joints {
                    #expect(
                        joint.x.isFinite && joint.y.isFinite && joint.z.isFinite,
                        "\(motion.rawValue) at phase \(phase) produced \(joint)"
                    )
                }
            }
        }
    }

    @Test("Phases outside 0...1 wrap instead of breaking")
    func phaseWrapsCleanly() {
        for motion in Self.allMotions {
            let base = MotionLibrary.pose(for: motion, phase: 0.3)
            for offset in [Float(-2), -1, 1, 2, 17] {
                let wrapped = MotionLibrary.pose(for: motion, phase: 0.3 + offset)
                #expect(
                    maximumDistance(base, wrapped) < 0.0005,
                    "\(motion.rawValue) does not wrap at phase offset \(offset)"
                )
            }
        }
    }

    @Test("Each loop closes on itself without a visible seam")
    func loopsAreContinuous() {
        for motion in Self.allMotions {
            let start = MotionLibrary.pose(for: motion, phase: 0)
            let end = MotionLibrary.pose(for: motion, phase: 0.999)
            #expect(
                maximumDistance(start, end) < 0.02,
                "\(motion.rawValue) jumps when the loop restarts"
            )
        }
    }

    @Test("No frame jumps relative to the rest of the movement")
    func motionHasNoVelocitySpikes() {
        // Sampled at the movement's own real frame rate rather than a fixed
        // count, because a slow exercise advances far less per frame than a fast
        // one and a shared sample count would judge them against the wrong bar.
        for motion in Self.allMotions {
            let advancePerFrame = MotionLibrary.metadata(for: motion).cyclesPerSecond / 60
            let frameCount = max(8, Int((1 / advancePerFrame).rounded()))

            var steps: [Float] = []
            for index in 0..<frameCount {
                let current = MotionLibrary.pose(for: motion, phase: Float(index) * advancePerFrame)
                let next = MotionLibrary.pose(for: motion, phase: Float(index + 1) * advancePerFrame)
                steps.append(maximumDistance(current, next))
            }

            let largest = steps.max() ?? 0
            let average = steps.reduce(0, +) / Float(steps.count)
            // The athlete is about 2.3 units tall, so 0.08 is roughly a frame
            // moving 3% of body height — brisk, but nothing that reads as a jump.
            #expect(largest < 0.08, "\(motion.rawValue) moves \(largest) in one frame")
            // And a true discontinuity shows up as one frame unlike its
            // neighbours, whatever the movement's overall speed. The absolute
            // floor keeps an isometric hold — where the average frame moves
            // almost nothing — from failing on a spike too small to see.
            #expect(
                largest < max(average * 6, 0.02),
                "\(motion.rawValue) spikes to \(largest) against an average of \(average)"
            )
        }
    }

    @Test("The body never sinks through the mat")
    func nothingClipsTheGround() {
        for motion in Self.allMotions {
            for phase in Self.phases {
                let pose = MotionLibrary.pose(for: motion, phase: phase)
                let lowest = pose.joints.map(\.y).min() ?? 0
                #expect(
                    lowest >= MotionLibrary.groundLevel - 0.001,
                    "\(motion.rawValue) at phase \(phase) drops a joint to \(lowest)"
                )
            }
        }
    }

    @Test("The body stays inside the camera's framing")
    func posesStayInFrame() {
        for motion in Self.allMotions {
            for phase in Self.phases {
                let pose = MotionLibrary.pose(for: motion, phase: phase)
                for joint in pose.joints {
                    #expect(abs(joint.x) < 2.1, "\(motion.rawValue) reaches x=\(joint.x)")
                    // Standing movements are taller than anything on the mat.
                    #expect(joint.y < 2.4, "\(motion.rawValue) reaches y=\(joint.y)")
                    #expect(abs(joint.z) < 1.1, "\(motion.rawValue) reaches z=\(joint.z)")
                }
            }
        }
    }

    @Test("Every motion visibly animates")
    func everyMotionMoves() {
        for motion in Self.allMotions {
            let travel = Self.phases
                .map { maximumDistance(MotionLibrary.pose(for: motion, phase: 0), MotionLibrary.pose(for: motion, phase: $0)) }
                .max() ?? 0
            #expect(travel > 0.01, "\(motion.rawValue) is visually static")
        }
    }

    @Test("Left and right stay consistent for symmetric movements")
    func symmetricMovementsStaySymmetric() {
        // These movements load both sides identically; a drift between them
        // would show up as a lopsided athlete.
        let symmetric: [MotionKind] = [.crunch, .legRaise, .plank, .hollowHold, .bridge, .rest]

        for motion in symmetric {
            for phase in Self.phases {
                let pose = MotionLibrary.pose(for: motion, phase: phase)
                let pairs: [(SIMD3<Float>, SIMD3<Float>)] = [
                    (pose.leftShoulder, pose.rightShoulder),
                    (pose.leftHip, pose.rightHip),
                    (pose.leftKnee, pose.rightKnee),
                    (pose.leftAnkle, pose.rightAnkle),
                    (pose.leftElbow, pose.rightElbow),
                    (pose.leftHand, pose.rightHand)
                ]
                for (left, right) in pairs {
                    #expect(
                        abs(left.x - right.x) < 0.01 && abs(left.y - right.y) < 0.01,
                        "\(motion.rawValue) at phase \(phase) is lopsided: \(left) vs \(right)"
                    )
                    #expect(
                        abs(left.z + right.z) < 0.02,
                        "\(motion.rawValue) at phase \(phase) is off-centre: \(left.z) vs \(right.z)"
                    )
                }
            }
        }
    }

    @Test("Alternating movements actually trade sides")
    func alternatingMovementsSwapSides() {
        let alternating: [MotionKind] = [.bicycle, .deadBug, .birdDog, .plankReach, .flutter, .scissors]

        for motion in alternating {
            let poses = Self.phases.map { MotionLibrary.pose(for: motion, phase: $0) }
            // Different movements alternate along different axes — flutter kicks
            // trade height, scissors trade depth, a bicycle trades reach — so
            // the lead is measured on whichever axis actually carries it.
            let leads: [[Float]] = [
                poses.map { $0.leftAnkle.x - $0.rightAnkle.x },
                poses.map { $0.leftAnkle.y - $0.rightAnkle.y },
                poses.map { $0.leftAnkle.z - $0.rightAnkle.z },
                poses.map { $0.leftHand.x - $0.rightHand.x },
                poses.map { $0.leftHand.y - $0.rightHand.y }
            ]

            let swapsSides = leads.contains { lead in
                lead.contains { $0 > 0.05 } && lead.contains { $0 < -0.05 }
            }
            #expect(swapsSides, "\(motion.rawValue) favours one side for the whole cycle")
        }
    }

    @Test("A crunch curls the ribs toward the pelvis")
    func crunchRaisesTheChest() {
        let relaxed = MotionLibrary.pose(for: .crunch, phase: 0)
        let contracted = MotionLibrary.pose(for: .crunch, phase: MotionLibrary.tempo(for: .crunch).peakPhase)

        #expect(contracted.chest.y > relaxed.chest.y + 0.05)
        #expect(contracted.head.y > relaxed.head.y + 0.08)
        // Curling lifts the ribs and shortens the distance to the hips; it must
        // not simply slide the whole torso upward.
        #expect(
            simd_distance(contracted.chest, contracted.pelvis)
                <= simd_distance(relaxed.chest, relaxed.pelvis) + 0.001
        )
    }

    @Test("A leg raise sweeps the legs through a wide arc")
    func legRaiseSweepsTheLegs() {
        let low = MotionLibrary.pose(for: .legRaise, phase: 0)
        let high = MotionLibrary.pose(for: .legRaise, phase: MotionLibrary.tempo(for: .legRaise).peakPhase)

        #expect(high.leftAnkle.y > low.leftAnkle.y + 0.5)
        #expect(high.leftAnkle.x < low.leftAnkle.x)
    }

    @Test("A bridge lifts the hips while the shoulders stay down")
    func bridgeLiftsOnlyTheHips() {
        let down = MotionLibrary.pose(for: .bridge, phase: 0)
        let up = MotionLibrary.pose(for: .bridge, phase: MotionLibrary.tempo(for: .bridge).peakPhase)

        #expect(up.pelvis.y > down.pelvis.y + 0.15)
        #expect(abs(up.leftShoulder.y - down.leftShoulder.y) < 0.12)
        #expect(up.pelvis.y > up.leftShoulder.y)
    }

    @Test("Planks keep the body in a straight line")
    func planksStayAligned() {
        for motion in [MotionKind.plank, .plankReach, .mountainClimber] {
            for phase in Self.phases {
                let pose = MotionLibrary.pose(for: motion, phase: phase)
                let shoulders = (pose.leftShoulder + pose.rightShoulder) * 0.5
                // The hips must sit between the shoulders and the feet rather
                // than sagging to the mat or piking toward the ceiling.
                #expect(
                    pose.pelvis.y < shoulders.y + 0.12,
                    "\(motion.rawValue) at phase \(phase) pikes the hips"
                )
                #expect(
                    pose.pelvis.y > MotionLibrary.groundLevel + 0.14,
                    "\(motion.rawValue) at phase \(phase) sags the hips"
                )
            }
        }
    }

    @Test("The athlete faces the right way in every stance")
    func bodyFacesTheRightWay() {
        // The facing direction drives where the feet point and which oblique is
        // on which side, so getting a stance's handedness wrong turns the whole
        // body inside out.
        let facingUp: [MotionKind] = [.crunch, .legRaise, .reverseCrunch, .bridge, .hollowHold, .rest, .twist, .vSit]
        let facingDown: [MotionKind] = [.plank, .plankReach, .mountainClimber, .birdDog, .bearHold, .superman]

        for motion in facingUp {
            let pose = MotionLibrary.pose(for: motion, phase: 0.25)
            #expect(pose.front.y > 0.1, "\(motion.rawValue) is lying face down")
        }
        for motion in facingDown {
            let pose = MotionLibrary.pose(for: motion, phase: 0.25)
            #expect(pose.front.y < -0.1, "\(motion.rawValue) is lying on its back")
        }
    }

    @Test("Feet rest on the mat rather than through it")
    func feetStayOnTheGround() {
        for motion in Self.allMotions {
            for phase in Self.phases {
                let pose = MotionLibrary.pose(for: motion, phase: phase)
                #expect(
                    min(pose.leftToe.y, pose.rightToe.y) >= MotionLibrary.groundLevel - 0.001,
                    "\(motion.rawValue) at phase \(phase) pushes a toe to \(min(pose.leftToe.y, pose.rightToe.y))"
                )
            }
        }
    }

    @Test("Feet keep their shape whatever the leg is doing")
    func feetStayWellFormed() {
        // Tucked toes legitimately fold back under the shin — a bear hold and a
        // plank both do it — so the invariant is not direction but that the foot
        // keeps its length instead of collapsing into a stub.
        for motion in Self.allMotions {
            for phase in Self.phases {
                let pose = MotionLibrary.pose(for: motion, phase: phase)
                for (ankle, toe) in [
                    (pose.leftAnkle, pose.leftToe),
                    (pose.rightAnkle, pose.rightToe)
                ] {
                    let length = simd_distance(ankle, toe)
                    #expect(
                        abs(length - 0.148) < 0.002,
                        "\(motion.rawValue) at phase \(phase): the foot measures \(length)"
                    )
                }
            }
        }
    }

    private func maximumDistance(_ first: BodyPose, _ second: BodyPose) -> Float {
        zip(first.joints, second.joints)
            .map { simd_distance($0.0, $0.1) }
            .max() ?? 0
    }
}

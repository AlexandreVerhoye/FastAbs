import Foundation
import Testing
import simd
@testable import Hara

/// What each new movement is supposed to *look* like.
///
/// The motion-system suite already proves that no bone stretches, no joint jumps
/// and nothing sinks through the mat — all of which a completely wrong animation
/// can satisfy. A push-up whose chest rises on the way down passes every one of
/// them. These tests state the intent instead: what travels, in which direction,
/// and how far. They are the assertions that would have caught the squat drawn
/// as a tipped slab, and they cost nothing to keep.
@Suite("Full-body choreography")
struct FullBodyChoreographyTests {
    static let sampleCount = 64
    static let phases: [Float] = (0..<sampleCount).map { Float($0) / Float(sampleCount) }

    private func poses(_ motion: MotionKind) -> [BodyPose] {
        Self.phases.map { MotionLibrary.pose(for: motion, phase: $0) }
    }

    private func range(_ motion: MotionKind, _ value: (BodyPose) -> Float) -> (low: Float, high: Float) {
        let samples = poses(motion).map(value)
        return (samples.min() ?? 0, samples.max() ?? 0)
    }

    // MARK: - Pressing

    @Test("A push-up lowers the chest over hands that stay planted")
    func pushUpsPressFromTheFloor() {
        for motion in [MotionKind.pushUp, .kneePushUp, .wallPushUp] {
            let all = poses(motion)
            let hand = all.map(\.leftHand)
            let handTravel = zip(hand, hand.dropFirst()).map(simd_distance).max() ?? 0
            #expect(handTravel < 0.02, "\(motion.rawValue) slides its hands \(handTravel) between frames")

            // Measured as travel through space, not as height: a wall push-up
            // moves the chest toward the wall, and a version of this that only
            // watched `y` would call it broken.
            let chests = all.map(\.chest)
            let travel = chests.flatMap { a in chests.map { simd_distance(a, $0) } }.max() ?? 0
            #expect(travel > 0.15, "\(motion.rawValue) moves the chest only \(travel)")

            // And the arm has to have somewhere to bend: a target further away
            // than the arm is long pins the elbow straight for the whole cycle,
            // which is what drew every plank as a pencil line.
            let reach = all.map { simd_distance($0.leftShoulder, $0.leftHand) }.max() ?? 0
            let arm = SkeletonMetrics.standard.upperArm + SkeletonMetrics.standard.forearm
            #expect(reach < arm - 0.01, "\(motion.rawValue) reaches \(reach) with a \(arm) arm")
        }
    }

    @Test("A pike push-up keeps the hips above the shoulders")
    func pikeStaysInverted() {
        for pose in poses(.pikePushUp) {
            #expect(pose.pelvis.y > pose.chest.y, "the pike lost its inverted V")
        }
    }

    @Test("A floor dip drives the seat up and down over planted hands")
    func dipsMoveTheSeat() {
        let seat = range(.floorDip) { $0.pelvis.y }
        #expect(seat.high - seat.low > 0.08, "the seat moves only \(seat.high - seat.low)")
        for pose in poses(.floorDip) {
            #expect(pose.pelvis.y > MotionLibrary.groundLevel + 0.02, "the seat is resting on the mat")
        }
    }

    @Test("A row pulls the hands back toward the ribs")
    func rowsPullBack() {
        let all = poses(.proneRow)
        let spans = all.map { simd_distance($0.leftShoulder, $0.leftHand) }
        #expect((spans.max() ?? 0) - (spans.min() ?? 0) > 0.15, "the row barely bends an arm")
        // Both arms work together: this is not an alternating movement.
        for pose in all {
            #expect(abs(pose.leftHand.x - pose.rightHand.x) < 0.02, "the row went one-armed")
        }
    }

    // MARK: - Lower body

    @Test("A squat sinks the hips and keeps the feet down")
    func squatsSink() {
        let hips = range(.squat) { $0.pelvis.y }
        #expect(hips.high - hips.low > 0.25, "the squat drops only \(hips.high - hips.low)")

        for pose in poses(.squat) {
            #expect(
                abs(pose.leftAnkle.y - MotionLibrary.groundLevel) < 0.03,
                "a foot left the mat at \(pose.leftAnkle.y)"
            )
            // Hips behind the heels, which is what separates a squat from a
            // knee bend.
            #expect(pose.pelvis.x <= pose.leftAnkle.x + 0.05)
        }
    }

    @Test("A squat hold holds")
    func theHoldHolds() {
        let hips = range(.squatHold) { $0.pelvis.y }
        #expect(hips.high - hips.low < 0.05, "the hold travels \(hips.high - hips.low)")
        // Still breathing, though: a frozen frame reads as a broken animation.
        let chest = range(.squatHold) { $0.chest.y }
        #expect(chest.high - chest.low > 0.001)
        #expect(hips.low < 0.9, "the hold never actually sat down")
    }

    @Test("A good morning folds the trunk forward over the hips")
    func goodMorningsHinge() {
        let all = poses(.goodMorning)
        guard let tall = all.max(by: { $0.head.y < $1.head.y }),
              let folded = all.min(by: { $0.head.y < $1.head.y })
        else {
            Issue.record("no poses")
            return
        }

        #expect(tall.head.y - folded.head.y > 0.45, "the fold only drops the head \(tall.head.y - folded.head.y)")
        // Forward, not backward: the chest ends up on the +X side of the pelvis,
        // the same side a squat leans toward.
        #expect(folded.chest.x > folded.pelvis.x + 0.2, "the trunk folded the wrong way")
        // And the hips travel back as the chest comes forward — that is the
        // difference between a hinge and a bow.
        #expect(folded.pelvis.x < tall.pelvis.x - 0.05)
        // Knees stay long: this is not a squat.
        let knee = simd_distance(folded.leftHip, folded.leftAnkle)
        let leg = SkeletonMetrics.standard.thigh + SkeletonMetrics.standard.shin
        #expect(knee > leg * 0.85, "the good morning turned into a squat")
    }

    @Test("A donkey kick lifts one heel and leaves the pelvis alone")
    func donkeyKicksIsolate() {
        let all = poses(.donkeyKick)
        let pelvis = all.map(\.pelvis.y)
        #expect((pelvis.max() ?? 0) - (pelvis.min() ?? 0) < 0.08, "the pelvis rode up with the leg")

        let left = range(.donkeyKick) { $0.leftAnkle.y }
        let right = range(.donkeyKick) { $0.rightAnkle.y }
        #expect(left.high - left.low > 0.2, "the left heel barely moved")
        #expect(right.high - right.low > 0.2, "the right heel barely moved")
    }

    @Test("Alternating standing work uses both sides")
    func lungesAlternate() {
        for motion in [MotionKind.lunge, .lateralLunge] {
            let all = poses(motion)
            let leftBack = all.map { $0.leftAnkle.x - $0.rightAnkle.x }.min() ?? 0
            let rightBack = all.map { $0.leftAnkle.x - $0.rightAnkle.x }.max() ?? 0
            let leftWide = all.map { $0.leftAnkle.z }.min() ?? 0
            let rightWide = all.map { $0.rightAnkle.z }.max() ?? 0
            // Either the feet trade places along the body's length, or they
            // trade places across it — depending on which lunge this is.
            #expect(
                rightBack - leftBack > 0.3 || rightWide - leftWide > 0.6,
                "\(motion.rawValue) only ever moves one leg"
            )
        }
    }

    // MARK: - Compound

    @Test("A burpee visits the mat and stands back up")
    func burpeesGoAllTheWay() {
        for motion in [MotionKind.burpee, .squatThrust] {
            let hips = range(motion) { $0.pelvis.y }
            #expect(hips.low < 0.75, "\(motion.rawValue) never reaches the mat (lowest \(hips.low))")
            #expect(hips.high > 1.0, "\(motion.rawValue) never stands up (highest \(hips.high))")

            // The hands go to the mat and come back off it, which is the part
            // that makes it a burpee rather than a squat.
            let hands = range(motion) { $0.leftHand.y }
            #expect(hands.low < 0.25, "\(motion.rawValue) never puts a hand down")
            #expect(hands.high > 0.7, "\(motion.rawValue) never picks it back up")
        }
    }

    @Test("A jumping jack opens the legs while the arms rise")
    func jacksOpenAndClose() {
        let all = poses(.jumpingJack)
        let spread = all.map { abs($0.leftAnkle.z - $0.rightAnkle.z) }
        #expect((spread.max() ?? 0) - (spread.min() ?? 0) > 0.4, "the legs barely part")

        let hands = range(.jumpingJack) { $0.leftHand.y }
        #expect(hands.high - hands.low > 0.6, "the arms barely rise")

        // The two halves stay in step: a jack is symmetric.
        for pose in all {
            #expect(abs(pose.leftHand.y - pose.rightHand.y) < 0.02)
            #expect(abs(pose.leftAnkle.y - pose.rightAnkle.y) < 0.02)
        }
    }

    @Test("An up-down plank keeps the hips still")
    func upDownPlankStaysLevel() {
        let all = poses(.plankUpDown)
        let pelvis = all.map(\.pelvis.y)
        #expect((pelvis.max() ?? 0) - (pelvis.min() ?? 0) < 0.09, "the hips rode up and down instead")

        // One arm at a time, and both over a full cycle.
        let leftHand = range(.plankUpDown) { $0.leftHand.x }
        let rightHand = range(.plankUpDown) { $0.rightHand.x }
        #expect(leftHand.high - leftHand.low > 0.15, "the left arm never pressed up")
        #expect(rightHand.high - rightHand.low > 0.15, "the right arm never pressed up")
    }

    // MARK: - Every new movement at once

    /// The movements added with the whole-body catalog, so a new one cannot be
    /// added without appearing here.
    static let offTheMat: [MotionKind] = [
        .squat, .squatHold, .lunge, .lateralLunge, .wallSit, .calfRaise, .goodMorning,
        .donkeyKick, .pushUp, .kneePushUp, .wallPushUp, .pikePushUp, .floorDip,
        .proneRow, .plankUpDown, .squatThrust, .burpee, .jumpingJack
    ]

    @Test("Every new movement is choreographed, framed and loaded")
    func newMovementsAreComplete() {
        let catalogued = Set(ExerciseCatalog.all.map(\.motion))
        for motion in Self.offTheMat {
            #expect(catalogued.contains(motion), "\(motion.rawValue) belongs to no exercise")

            let metadata = MotionLibrary.metadata(for: motion)
            #expect(!metadata.title.isEmpty)
            #expect(!metadata.accessibilityDescription.isEmpty)
            #expect(metadata.cyclesPerSecond > 0)

            let load = MotionLibrary.load(for: motion)
            let total = [
                load.upperAbs, load.lowerAbs, load.obliques, load.deepCore, load.lowerBack,
                load.glutes, load.quadriceps, load.hamstrings, load.calves,
                load.chest, load.shoulders, load.arms, load.upperBack
            ].reduce(0, +)
            #expect(total > 0.5, "\(motion.rawValue) loads nothing")
        }
    }

    @Test("Limbs never stand fully upright inside the trunk")
    func limbsStayOutsideTheTrunk() {
        // A limb collapsed onto the spine draws as a body with a leg missing.
        for motion in Self.offTheMat {
            for pose in poses(motion) {
                for ankle in [pose.leftAnkle, pose.rightAnkle] {
                    let toSpine = simd_distance(
                        SIMD3<Float>(ankle.x, ankle.y, 0),
                        SIMD3<Float>(pose.pelvis.x, pose.pelvis.y, 0)
                    )
                    #expect(toSpine > 0.1, "\(motion.rawValue) folds an ankle into the pelvis")
                }
            }
        }
    }

    @Test("The activation model lights the muscles the movement uses")
    func activationReachesTheWholeBody() {
        // A squat that lights only the abdomen is the figure telling the athlete
        // something untrue about what they just did.
        let squat = MuscleActivation.make(for: .squat, phase: 0.3, focus: [.quadriceps, .glutes])
        #expect(squat.quadriceps > 0.3)
        #expect(squat.glutes > 0.3)

        let press = MuscleActivation.make(for: .pushUp, phase: 0.3, focus: [.chest])
        #expect(press.chest > 0.3)
        #expect(press.arms > 0.1)

        for motion in Self.offTheMat {
            for phase in [Float(0), 0.25, 0.5, 0.75] {
                let activation = MuscleActivation.make(for: motion, phase: phase)
                #expect(activation.isValid, "\(motion.rawValue) produced an impossible activation")
                #expect(activation.overall > 0, "\(motion.rawValue) lights nothing at phase \(phase)")
            }
        }
    }
}

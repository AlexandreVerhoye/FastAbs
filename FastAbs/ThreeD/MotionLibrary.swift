import Foundation
import simd

/// The compact, renderer-facing representation of a human pose.
///
/// Positions use RealityKit's right-handed coordinates: X runs from head to
/// feet, Y points up from the mat, and Z separates the left and right sides.
struct BodyPose {
    var head: SIMD3<Float>
    var neck: SIMD3<Float>
    var chest: SIMD3<Float>
    var pelvis: SIMD3<Float>
    var leftShoulder: SIMD3<Float>
    var rightShoulder: SIMD3<Float>
    var leftElbow: SIMD3<Float>
    var rightElbow: SIMD3<Float>
    var leftHand: SIMD3<Float>
    var rightHand: SIMD3<Float>
    var leftHip: SIMD3<Float>
    var rightHip: SIMD3<Float>
    var leftKnee: SIMD3<Float>
    var rightKnee: SIMD3<Float>
    var leftAnkle: SIMD3<Float>
    var rightAnkle: SIMD3<Float>
}

struct MotionVisualMetadata {
    let title: String
    let accessibilityDescription: String
    let cyclesPerSecond: Float
    let cameraTarget: SIMD3<Float>
    let cameraPosition: SIMD3<Float>
}

enum MotionLibrary {
    static func metadata(for motion: MotionKind) -> MotionVisualMetadata {
        let title: String
        let description: String
        let cadence: Float

        switch motion {
        case .crunch:
            (title, description, cadence) = ("Crunch", "Le haut du buste s'enroule vers le bassin puis revient avec contrôle.", 0.35)
        case .reverseCrunch:
            (title, description, cadence) = ("Crunch inversé", "Les genoux reviennent vers la poitrine et le bassin se décolle légèrement.", 0.32)
        case .toeReach:
            (title, description, cadence) = ("Toucher de pointes", "Les jambes restent verticales pendant que les mains montent vers les chevilles.", 0.38)
        case .legRaise:
            (title, description, cadence) = ("Relevé de jambes", "Les jambes tendues montent ensemble puis redescendent sans creuser le dos.", 0.25)
        case .hipRaise:
            (title, description, cadence) = ("Relevé de bassin", "Le bassin s'enroule au-dessus du tapis tandis que les genoux se rapprochent du buste.", 0.3)
        case .flutter:
            (title, description, cadence) = ("Battements", "Les jambes tendues alternent de petits battements au-dessus du tapis.", 0.75)
        case .scissors:
            (title, description, cadence) = ("Ciseaux", "Les jambes tendues se croisent horizontalement de façon alternée.", 0.65)
        case .bicycle:
            (title, description, cadence) = ("Bicyclette", "Un genou revient tandis que la jambe opposée s'allonge et que le buste tourne.", 0.48)
        case .twist:
            (title, description, cadence) = ("Rotations russes", "Le buste assis pivote de gauche à droite avec les mains jointes.", 0.42)
        case .obliqueCrunch:
            (title, description, cadence) = ("Crunch oblique", "Chaque épaule se rapproche alternativement du genou opposé.", 0.4)
        case .heelTap:
            (title, description, cadence) = ("Toucher de talons", "Le buste fléchi s'incline alternativement vers chaque talon.", 0.55)
        case .plank:
            (title, description, cadence) = ("Planche", "Le corps reste aligné des épaules aux chevilles avec une respiration calme.", 0.12)
        case .sidePlank:
            (title, description, cadence) = ("Planche latérale", "Le corps reste aligné sur le côté et le bassin descend légèrement puis remonte.", 0.24)
        case .plankReach:
            (title, description, cadence) = ("Planche bras tendu", "Un bras s'allonge devant le corps pendant que le bassin reste stable.", 0.3)
        case .mountainClimber:
            (title, description, cadence) = ("Grimpeur", "Les genoux reviennent rapidement et alternativement sous la poitrine.", 0.72)
        case .hollowHold:
            (title, description, cadence) = ("Banane", "Bras et jambes restent allongés au-dessus du tapis avec les lombaires stables.", 0.14)
        case .deadBug:
            (title, description, cadence) = ("Insecte mort", "Un bras et la jambe opposée s'allongent pendant que le tronc reste immobile.", 0.28)
        case .birdDog:
            (title, description, cadence) = ("Chien-oiseau", "À quatre pattes, un bras et la jambe opposée s'allongent.", 0.25)
        case .bearHold:
            (title, description, cadence) = ("Ours", "Les genoux restent au-dessus du sol et les appuis alternent doucement.", 0.3)
        case .vSit:
            (title, description, cadence) = ("Maintien en V", "Le buste et les jambes s'éloignent puis reviennent autour d'un bassin stable.", 0.27)
        case .superman:
            (title, description, cadence) = ("Superman", "Allongé sur le ventre, les bras et les jambes se soulèvent avec une faible amplitude.", 0.24)
        case .bridge:
            (title, description, cadence) = ("Pont", "Le bassin monte jusqu'à aligner épaules, hanches et genoux puis redescend.", 0.28)
        case .rest:
            (title, description, cadence) = ("Récupération", "Le corps reste allongé et le thorax accompagne une respiration lente.", 0.1)
        }

        return MotionVisualMetadata(
            title: title,
            accessibilityDescription: description,
            cyclesPerSecond: cadence,
            cameraTarget: SIMD3<Float>(0, 0.55, 0),
            cameraPosition: SIMD3<Float>(3.25, 2.45, 4.15)
        )
    }

    static func pose(for motion: MotionKind, phase rawPhase: Float) -> BodyPose {
        let phase = rawPhase - floor(rawPhase)
        let lift = 0.5 - 0.5 * cos(phase * 2 * .pi)
        let alternating = sin(phase * 2 * .pi)

        switch motion {
        case .crunch:
            var pose = supineBentKnees()
            curlTorso(&pose, amount: lift * 0.72)
            return pose

        case .reverseCrunch:
            var pose = supineBentKnees()
            tuckLegs(&pose, amount: lift * 0.9)
            pose.pelvis.y += lift * 0.22
            pose.leftHip.y += lift * 0.22
            pose.rightHip.y += lift * 0.22
            return pose

        case .toeReach:
            var pose = supineLegsRaised()
            curlTorso(&pose, amount: lift * 0.68)
            pose.leftElbow = mix(pose.leftShoulder, pose.leftAnkle, t: 0.55 + lift * 0.2)
            pose.rightElbow = mix(pose.rightShoulder, pose.rightAnkle, t: 0.55 + lift * 0.2)
            pose.leftHand = mix(pose.leftShoulder, pose.leftAnkle, t: 0.72 + lift * 0.24)
            pose.rightHand = mix(pose.rightShoulder, pose.rightAnkle, t: 0.72 + lift * 0.24)
            return pose

        case .legRaise:
            var pose = supineStraight()
            let angle = mix(0.18, 1.25, t: lift)
            setStraightLegs(&pose, angle: angle)
            return pose

        case .hipRaise:
            var pose = supineBentKnees()
            tuckLegs(&pose, amount: lift)
            let rise = lift * 0.27
            translateHips(&pose, by: SIMD3<Float>(-rise * 0.25, rise, 0))
            return pose

        case .flutter:
            var pose = supineStraight()
            setStraightLegs(&pose, angle: 0.2)
            pose.leftAnkle.y += alternating * 0.18
            pose.rightAnkle.y -= alternating * 0.18
            pose.leftKnee.y += alternating * 0.08
            pose.rightKnee.y -= alternating * 0.08
            return pose

        case .scissors:
            var pose = supineStraight()
            setStraightLegs(&pose, angle: 0.25)
            pose.leftAnkle.z = alternating * 0.25
            pose.rightAnkle.z = -alternating * 0.25
            pose.leftKnee.z = alternating * 0.13
            pose.rightKnee.z = -alternating * 0.13
            return pose

        case .bicycle:
            var pose = supineBentKnees()
            let leftTuck = 0.5 + alternating * 0.5
            setBicycleLegs(&pose, leftTuck: leftTuck)
            curlTorso(&pose, amount: 0.62)
            twistShoulders(&pose, amount: -alternating * 0.36)
            return pose

        case .twist:
            var pose = seated()
            twistShoulders(&pose, amount: alternating * 0.58)
            let handCenter = pose.chest + SIMD3<Float>(0.18, -0.12, alternating * 0.52)
            pose.leftHand = handCenter + SIMD3<Float>(0, 0, 0.07)
            pose.rightHand = handCenter - SIMD3<Float>(0, 0, 0.07)
            pose.leftElbow = mix(pose.leftShoulder, pose.leftHand, t: 0.58)
            pose.rightElbow = mix(pose.rightShoulder, pose.rightHand, t: 0.58)
            return pose

        case .obliqueCrunch:
            var pose = supineBentKnees()
            curlTorso(&pose, amount: 0.25 + abs(alternating) * 0.48)
            twistShoulders(&pose, amount: alternating * 0.46)
            return pose

        case .heelTap:
            var pose = supineBentKnees()
            curlTorso(&pose, amount: 0.38)
            let side = alternating
            pose.chest.z += side * 0.12
            pose.neck.z += side * 0.16
            pose.head.z += side * 0.18
            pose.leftHand.z += max(side, 0) * 0.1
            pose.rightHand.z += min(side, 0) * 0.1
            pose.leftHand.x += max(side, 0) * 0.28
            pose.rightHand.x += max(-side, 0) * 0.28
            return pose

        case .plank:
            var pose = forearmPlank()
            pose.chest.y += sin(phase * 2 * .pi) * 0.015
            return pose

        case .sidePlank:
            var pose = sidePlank()
            let drop = lift * 0.16
            translateHips(&pose, by: SIMD3<Float>(0, -drop, 0))
            return pose

        case .plankReach:
            var pose = highPlank()
            let leftReaches = alternating >= 0
            let reach = abs(alternating)
            if leftReaches {
                pose.leftElbow = mix(pose.leftShoulder, SIMD3<Float>(-1.25, 0.64, 0.2), t: reach)
                pose.leftHand = mix(pose.leftHand, SIMD3<Float>(-1.5, 0.72, 0.2), t: reach)
            } else {
                pose.rightElbow = mix(pose.rightShoulder, SIMD3<Float>(-1.25, 0.64, -0.2), t: reach)
                pose.rightHand = mix(pose.rightHand, SIMD3<Float>(-1.5, 0.72, -0.2), t: reach)
            }
            return pose

        case .mountainClimber:
            var pose = highPlank()
            let leftTuck = 0.5 + alternating * 0.5
            mountainClimberLegs(&pose, leftTuck: leftTuck)
            return pose

        case .hollowHold:
            var pose = supineStraight()
            setStraightLegs(&pose, angle: 0.28 + alternating * 0.025)
            pose.leftElbow = SIMD3<Float>(-1.2, 0.42, 0.18)
            pose.rightElbow = SIMD3<Float>(-1.2, 0.42, -0.18)
            pose.leftHand = SIMD3<Float>(-1.48, 0.5, 0.16)
            pose.rightHand = SIMD3<Float>(-1.48, 0.5, -0.16)
            curlTorso(&pose, amount: 0.22)
            return pose

        case .deadBug:
            var pose = supineTabletop()
            let leftExtends = alternating >= 0
            let reach = abs(alternating)
            if leftExtends {
                extendDeadBug(&pose, leftSide: true, amount: reach)
            } else {
                extendDeadBug(&pose, leftSide: false, amount: reach)
            }
            return pose

        case .birdDog:
            var pose = quadruped()
            let leftArm = alternating >= 0
            extendBirdDog(&pose, leftArm: leftArm, amount: abs(alternating))
            return pose

        case .bearHold:
            var pose = quadruped()
            pose.leftKnee.y += 0.12
            pose.rightKnee.y += 0.12
            pose.leftAnkle.y += 0.08
            pose.rightAnkle.y += 0.08
            let handLift = abs(alternating) * 0.08
            if alternating >= 0 {
                pose.leftHand.y += handLift
                pose.leftElbow.y += handLift * 0.5
            } else {
                pose.rightHand.y += handLift
                pose.rightElbow.y += handLift * 0.5
            }
            return pose

        case .vSit:
            var pose = seated()
            let extensionAmount = lift * 0.72
            pose.chest = mix(pose.chest, SIMD3<Float>(-0.48, 0.68, 0), t: extensionAmount)
            pose.neck = mix(pose.neck, SIMD3<Float>(-0.7, 0.87, 0), t: extensionAmount)
            pose.head = mix(pose.head, SIMD3<Float>(-0.88, 1.02, 0), t: extensionAmount)
            pose.leftKnee = mix(pose.leftKnee, SIMD3<Float>(0.72, 0.56, 0.16), t: extensionAmount)
            pose.rightKnee = mix(pose.rightKnee, SIMD3<Float>(0.72, 0.56, -0.16), t: extensionAmount)
            pose.leftAnkle = mix(pose.leftAnkle, SIMD3<Float>(1.16, 0.42, 0.16), t: extensionAmount)
            pose.rightAnkle = mix(pose.rightAnkle, SIMD3<Float>(1.16, 0.42, -0.16), t: extensionAmount)
            return pose

        case .superman:
            var pose = prone()
            let rise = lift * 0.25
            pose.head.y += rise * 0.65
            pose.neck.y += rise * 0.55
            pose.leftHand.y += rise
            pose.rightHand.y += rise
            pose.leftElbow.y += rise * 0.8
            pose.rightElbow.y += rise * 0.8
            pose.leftAnkle.y += rise * 0.7
            pose.rightAnkle.y += rise * 0.7
            pose.leftKnee.y += rise * 0.45
            pose.rightKnee.y += rise * 0.45
            return pose

        case .bridge:
            var pose = supineBentKnees()
            let rise = lift * 0.52
            translateHips(&pose, by: SIMD3<Float>(0, rise, 0))
            pose.chest.y += rise * 0.3
            pose.leftShoulder.y += rise * 0.12
            pose.rightShoulder.y += rise * 0.12
            return pose

        case .rest:
            var pose = supineBentKnees()
            pose.chest.y += lift * 0.035
            pose.leftShoulder.y += lift * 0.018
            pose.rightShoulder.y += lift * 0.018
            return pose
        }
    }
}

private extension MotionLibrary {
    static func supineBentKnees() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-1.12, 0.25, 0),
            neck: SIMD3<Float>(-0.91, 0.23, 0),
            chest: SIMD3<Float>(-0.57, 0.22, 0),
            pelvis: SIMD3<Float>(0.02, 0.2, 0),
            leftShoulder: SIMD3<Float>(-0.57, 0.22, 0.27),
            rightShoulder: SIMD3<Float>(-0.57, 0.22, -0.27),
            leftElbow: SIMD3<Float>(-0.2, 0.17, 0.38),
            rightElbow: SIMD3<Float>(-0.2, 0.17, -0.38),
            leftHand: SIMD3<Float>(0.18, 0.13, 0.39),
            rightHand: SIMD3<Float>(0.18, 0.13, -0.39),
            leftHip: SIMD3<Float>(0.03, 0.2, 0.16),
            rightHip: SIMD3<Float>(0.03, 0.2, -0.16),
            leftKnee: SIMD3<Float>(0.54, 0.68, 0.17),
            rightKnee: SIMD3<Float>(0.54, 0.68, -0.17),
            leftAnkle: SIMD3<Float>(0.98, 0.13, 0.18),
            rightAnkle: SIMD3<Float>(0.98, 0.13, -0.18)
        )
    }

    static func supineStraight() -> BodyPose {
        var pose = supineBentKnees()
        pose.leftKnee = SIMD3<Float>(0.62, 0.15, 0.16)
        pose.rightKnee = SIMD3<Float>(0.62, 0.15, -0.16)
        pose.leftAnkle = SIMD3<Float>(1.25, 0.13, 0.15)
        pose.rightAnkle = SIMD3<Float>(1.25, 0.13, -0.15)
        return pose
    }

    static func supineLegsRaised() -> BodyPose {
        var pose = supineStraight()
        pose.leftKnee = SIMD3<Float>(0.08, 0.8, 0.16)
        pose.rightKnee = SIMD3<Float>(0.08, 0.8, -0.16)
        pose.leftAnkle = SIMD3<Float>(0.03, 1.38, 0.15)
        pose.rightAnkle = SIMD3<Float>(0.03, 1.38, -0.15)
        return pose
    }

    static func supineTabletop() -> BodyPose {
        var pose = supineBentKnees()
        pose.leftKnee = SIMD3<Float>(0.14, 0.83, 0.17)
        pose.rightKnee = SIMD3<Float>(0.14, 0.83, -0.17)
        pose.leftAnkle = SIMD3<Float>(0.7, 0.8, 0.17)
        pose.rightAnkle = SIMD3<Float>(0.7, 0.8, -0.17)
        pose.leftElbow = SIMD3<Float>(-0.58, 0.78, 0.27)
        pose.rightElbow = SIMD3<Float>(-0.58, 0.78, -0.27)
        pose.leftHand = SIMD3<Float>(-0.55, 1.17, 0.24)
        pose.rightHand = SIMD3<Float>(-0.55, 1.17, -0.24)
        return pose
    }

    static func highPlank() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-1.0, 0.88, 0),
            neck: SIMD3<Float>(-0.81, 0.82, 0),
            chest: SIMD3<Float>(-0.48, 0.73, 0),
            pelvis: SIMD3<Float>(0.13, 0.62, 0),
            leftShoulder: SIMD3<Float>(-0.48, 0.72, 0.25),
            rightShoulder: SIMD3<Float>(-0.48, 0.72, -0.25),
            leftElbow: SIMD3<Float>(-0.5, 0.43, 0.25),
            rightElbow: SIMD3<Float>(-0.5, 0.43, -0.25),
            leftHand: SIMD3<Float>(-0.5, 0.12, 0.25),
            rightHand: SIMD3<Float>(-0.5, 0.12, -0.25),
            leftHip: SIMD3<Float>(0.13, 0.61, 0.16),
            rightHip: SIMD3<Float>(0.13, 0.61, -0.16),
            leftKnee: SIMD3<Float>(0.65, 0.39, 0.15),
            rightKnee: SIMD3<Float>(0.65, 0.39, -0.15),
            leftAnkle: SIMD3<Float>(1.18, 0.12, 0.14),
            rightAnkle: SIMD3<Float>(1.18, 0.12, -0.14)
        )
    }

    static func forearmPlank() -> BodyPose {
        var pose = highPlank()
        pose.leftElbow = SIMD3<Float>(-0.5, 0.13, 0.25)
        pose.rightElbow = SIMD3<Float>(-0.5, 0.13, -0.25)
        pose.leftHand = SIMD3<Float>(-0.9, 0.12, 0.22)
        pose.rightHand = SIMD3<Float>(-0.9, 0.12, -0.22)
        return pose
    }

    static func quadruped() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-0.84, 0.82, 0),
            neck: SIMD3<Float>(-0.66, 0.75, 0),
            chest: SIMD3<Float>(-0.35, 0.68, 0),
            pelvis: SIMD3<Float>(0.24, 0.66, 0),
            leftShoulder: SIMD3<Float>(-0.38, 0.67, 0.24),
            rightShoulder: SIMD3<Float>(-0.38, 0.67, -0.24),
            leftElbow: SIMD3<Float>(-0.42, 0.39, 0.24),
            rightElbow: SIMD3<Float>(-0.42, 0.39, -0.24),
            leftHand: SIMD3<Float>(-0.45, 0.12, 0.24),
            rightHand: SIMD3<Float>(-0.45, 0.12, -0.24),
            leftHip: SIMD3<Float>(0.24, 0.65, 0.17),
            rightHip: SIMD3<Float>(0.24, 0.65, -0.17),
            leftKnee: SIMD3<Float>(0.31, 0.14, 0.18),
            rightKnee: SIMD3<Float>(0.31, 0.14, -0.18),
            leftAnkle: SIMD3<Float>(0.73, 0.12, 0.18),
            rightAnkle: SIMD3<Float>(0.73, 0.12, -0.18)
        )
    }

    static func seated() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-0.56, 1.31, 0),
            neck: SIMD3<Float>(-0.44, 1.11, 0),
            chest: SIMD3<Float>(-0.29, 0.82, 0),
            pelvis: SIMD3<Float>(0.02, 0.25, 0),
            leftShoulder: SIMD3<Float>(-0.3, 0.9, 0.26),
            rightShoulder: SIMD3<Float>(-0.3, 0.9, -0.26),
            leftElbow: SIMD3<Float>(0.02, 0.73, 0.3),
            rightElbow: SIMD3<Float>(0.02, 0.73, -0.3),
            leftHand: SIMD3<Float>(0.29, 0.63, 0.19),
            rightHand: SIMD3<Float>(0.29, 0.63, -0.19),
            leftHip: SIMD3<Float>(0.03, 0.26, 0.17),
            rightHip: SIMD3<Float>(0.03, 0.26, -0.17),
            leftKnee: SIMD3<Float>(0.45, 0.76, 0.17),
            rightKnee: SIMD3<Float>(0.45, 0.76, -0.17),
            leftAnkle: SIMD3<Float>(0.83, 0.23, 0.17),
            rightAnkle: SIMD3<Float>(0.83, 0.23, -0.17)
        )
    }

    static func prone() -> BodyPose {
        var pose = supineStraight()
        pose.head.y = 0.23
        pose.neck.y = 0.2
        pose.chest.y = 0.18
        pose.pelvis.y = 0.17
        pose.leftShoulder.y = 0.18
        pose.rightShoulder.y = 0.18
        pose.leftElbow = SIMD3<Float>(-0.93, 0.16, 0.2)
        pose.rightElbow = SIMD3<Float>(-0.93, 0.16, -0.2)
        pose.leftHand = SIMD3<Float>(-1.33, 0.14, 0.16)
        pose.rightHand = SIMD3<Float>(-1.33, 0.14, -0.16)
        return pose
    }

    static func sidePlank() -> BodyPose {
        var pose = highPlank()
        pose.head = SIMD3<Float>(-0.98, 0.88, 0)
        pose.neck = SIMD3<Float>(-0.78, 0.8, 0)
        pose.chest = SIMD3<Float>(-0.47, 0.71, 0)
        pose.pelvis = SIMD3<Float>(0.14, 0.53, 0)
        pose.leftShoulder = SIMD3<Float>(-0.47, 0.72, 0.12)
        pose.rightShoulder = SIMD3<Float>(-0.47, 0.7, -0.12)
        pose.leftElbow = SIMD3<Float>(-0.47, 0.38, 0.11)
        pose.leftHand = SIMD3<Float>(-0.47, 0.12, 0.1)
        pose.rightElbow = SIMD3<Float>(-0.43, 1.02, -0.1)
        pose.rightHand = SIMD3<Float>(-0.4, 1.34, -0.08)
        pose.leftHip = SIMD3<Float>(0.14, 0.54, 0.09)
        pose.rightHip = SIMD3<Float>(0.14, 0.52, -0.09)
        pose.leftKnee = SIMD3<Float>(0.66, 0.35, 0.07)
        pose.rightKnee = SIMD3<Float>(0.66, 0.33, -0.07)
        pose.leftAnkle = SIMD3<Float>(1.17, 0.14, 0.06)
        pose.rightAnkle = SIMD3<Float>(1.17, 0.12, -0.06)
        return pose
    }

    static func curlTorso(_ pose: inout BodyPose, amount: Float) {
        pose.chest += SIMD3<Float>(0.19 * amount, 0.35 * amount, 0)
        pose.neck += SIMD3<Float>(0.28 * amount, 0.43 * amount, 0)
        pose.head += SIMD3<Float>(0.34 * amount, 0.46 * amount, 0)
        pose.leftShoulder += SIMD3<Float>(0.2 * amount, 0.35 * amount, 0)
        pose.rightShoulder += SIMD3<Float>(0.2 * amount, 0.35 * amount, 0)
        pose.leftElbow += SIMD3<Float>(0.12 * amount, 0.18 * amount, 0)
        pose.rightElbow += SIMD3<Float>(0.12 * amount, 0.18 * amount, 0)
    }

    static func twistShoulders(_ pose: inout BodyPose, amount: Float) {
        pose.leftShoulder.z -= amount * 0.19
        pose.rightShoulder.z -= amount * 0.19
        pose.leftShoulder.x += amount * 0.07
        pose.rightShoulder.x -= amount * 0.07
        pose.neck.z -= amount * 0.05
        pose.head.z -= amount * 0.07
    }

    static func tuckLegs(_ pose: inout BodyPose, amount: Float) {
        pose.leftKnee = mix(pose.leftKnee, SIMD3<Float>(0.08, 0.72, 0.17), t: amount)
        pose.rightKnee = mix(pose.rightKnee, SIMD3<Float>(0.08, 0.72, -0.17), t: amount)
        pose.leftAnkle = mix(pose.leftAnkle, SIMD3<Float>(0.4, 0.92, 0.17), t: amount)
        pose.rightAnkle = mix(pose.rightAnkle, SIMD3<Float>(0.4, 0.92, -0.17), t: amount)
    }

    static func translateHips(_ pose: inout BodyPose, by offset: SIMD3<Float>) {
        pose.pelvis += offset
        pose.leftHip += offset
        pose.rightHip += offset
    }

    static func setStraightLegs(_ pose: inout BodyPose, angle: Float) {
        let hipLeft = pose.leftHip
        let hipRight = pose.rightHip
        let kneeOffset = SIMD3<Float>(cos(angle) * 0.58, sin(angle) * 0.58, 0)
        let ankleOffset = SIMD3<Float>(cos(angle) * 1.18, sin(angle) * 1.18, 0)
        pose.leftKnee = hipLeft + kneeOffset
        pose.rightKnee = hipRight + kneeOffset
        pose.leftAnkle = hipLeft + ankleOffset
        pose.rightAnkle = hipRight + ankleOffset
    }

    static func setBicycleLegs(_ pose: inout BodyPose, leftTuck: Float) {
        let extendedLeftKnee = SIMD3<Float>(0.58, 0.3, 0.16)
        let extendedLeftAnkle = SIMD3<Float>(1.16, 0.2, 0.16)
        let tuckedLeftKnee = SIMD3<Float>(0.03, 0.73, 0.17)
        let tuckedLeftAnkle = SIMD3<Float>(0.35, 0.82, 0.17)
        pose.leftKnee = mix(extendedLeftKnee, tuckedLeftKnee, t: leftTuck)
        pose.leftAnkle = mix(extendedLeftAnkle, tuckedLeftAnkle, t: leftTuck)
        pose.rightKnee = mix(SIMD3<Float>(0.03, 0.73, -0.17), SIMD3<Float>(0.58, 0.3, -0.16), t: leftTuck)
        pose.rightAnkle = mix(SIMD3<Float>(0.35, 0.82, -0.17), SIMD3<Float>(1.16, 0.2, -0.16), t: leftTuck)
    }

    static func mountainClimberLegs(_ pose: inout BodyPose, leftTuck: Float) {
        pose.leftKnee = mix(SIMD3<Float>(0.64, 0.38, 0.15), SIMD3<Float>(-0.02, 0.57, 0.18), t: leftTuck)
        pose.leftAnkle = mix(SIMD3<Float>(1.18, 0.12, 0.14), SIMD3<Float>(0.43, 0.14, 0.18), t: leftTuck)
        pose.rightKnee = mix(SIMD3<Float>(-0.02, 0.57, -0.18), SIMD3<Float>(0.64, 0.38, -0.15), t: leftTuck)
        pose.rightAnkle = mix(SIMD3<Float>(0.43, 0.14, -0.18), SIMD3<Float>(1.18, 0.12, -0.14), t: leftTuck)
    }

    static func extendDeadBug(_ pose: inout BodyPose, leftSide: Bool, amount: Float) {
        if leftSide {
            pose.leftKnee = mix(pose.leftKnee, SIMD3<Float>(0.58, 0.34, 0.17), t: amount)
            pose.leftAnkle = mix(pose.leftAnkle, SIMD3<Float>(1.12, 0.22, 0.16), t: amount)
            pose.rightElbow = mix(pose.rightElbow, SIMD3<Float>(-1.0, 0.45, -0.2), t: amount)
            pose.rightHand = mix(pose.rightHand, SIMD3<Float>(-1.38, 0.34, -0.18), t: amount)
        } else {
            pose.rightKnee = mix(pose.rightKnee, SIMD3<Float>(0.58, 0.34, -0.17), t: amount)
            pose.rightAnkle = mix(pose.rightAnkle, SIMD3<Float>(1.12, 0.22, -0.16), t: amount)
            pose.leftElbow = mix(pose.leftElbow, SIMD3<Float>(-1.0, 0.45, 0.2), t: amount)
            pose.leftHand = mix(pose.leftHand, SIMD3<Float>(-1.38, 0.34, 0.18), t: amount)
        }
    }

    static func extendBirdDog(_ pose: inout BodyPose, leftArm: Bool, amount: Float) {
        if leftArm {
            pose.leftElbow = mix(pose.leftElbow, SIMD3<Float>(-0.95, 0.67, 0.22), t: amount)
            pose.leftHand = mix(pose.leftHand, SIMD3<Float>(-1.35, 0.68, 0.2), t: amount)
            pose.rightKnee = mix(pose.rightKnee, SIMD3<Float>(0.73, 0.63, -0.17), t: amount)
            pose.rightAnkle = mix(pose.rightAnkle, SIMD3<Float>(1.2, 0.66, -0.16), t: amount)
        } else {
            pose.rightElbow = mix(pose.rightElbow, SIMD3<Float>(-0.95, 0.67, -0.22), t: amount)
            pose.rightHand = mix(pose.rightHand, SIMD3<Float>(-1.35, 0.68, -0.2), t: amount)
            pose.leftKnee = mix(pose.leftKnee, SIMD3<Float>(0.73, 0.63, 0.17), t: amount)
            pose.leftAnkle = mix(pose.leftAnkle, SIMD3<Float>(1.2, 0.66, 0.16), t: amount)
        }
    }

    static func mix(_ a: Float, _ b: Float, t: Float) -> Float {
        a + (b - a) * min(max(t, 0), 1)
    }

    static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        a + (b - a) * min(max(t, 0), 1)
    }
}

import Foundation
import simd

struct MotionVisualMetadata: Equatable, Sendable {
    let title: String
    let accessibilityDescription: String
    let cyclesPerSecond: Float
    let cameraTarget: SIMD3<Float>
    let cameraPosition: SIMD3<Float>
}

/// The choreography of every exercise: how a movement is framed, how fast it
/// repeats, which muscles it loads, and where each joint sits at any instant.
///
/// Poses are authored as targets a coach would recognise — "heel toward the
/// hip", "hand planted under the shoulder". `PoseSolver` turns those targets
/// into an anatomically rigid pose, so choreography never has to do arithmetic
/// on bone lengths.
enum MotionLibrary {
    /// Height at which a joint is considered to be resting on the mat.
    static var groundLevel: Float { BodyPose.matHeight }

    static func metadata(for motion: MotionKind) -> MotionVisualMetadata {
        let title: String
        let description: String
        let cadence: Float

        switch motion {
        case .crunch:
            (title, description, cadence) = ("Crunch", "Le haut du buste s’enroule vers le bassin puis redescend avec contrôle.", 0.34)
        case .reverseCrunch:
            (title, description, cadence) = ("Crunch inversé", "Les genoux reviennent vers la poitrine et le bassin se décolle légèrement du tapis.", 0.32)
        case .toeReach:
            (title, description, cadence) = ("Toucher de pointes", "Les jambes restent verticales pendant que les mains montent vers les chevilles.", 0.36)
        case .legRaise:
            (title, description, cadence) = ("Relevé de jambes", "Les jambes tendues montent ensemble puis redescendent sans creuser le bas du dos.", 0.26)
        case .hipRaise:
            (title, description, cadence) = ("Relevé de bassin", "Le bassin s’enroule au-dessus du tapis tandis que les genoux se rapprochent du buste.", 0.3)
        case .flutter:
            (title, description, cadence) = ("Battements", "Les jambes tendues alternent de petits battements au-dessus du tapis.", 0.7)
        case .scissors:
            (title, description, cadence) = ("Ciseaux", "Les jambes tendues se croisent horizontalement de façon alternée.", 0.6)
        case .bicycle:
            (title, description, cadence) = ("Bicyclette", "Un genou revient pendant que la jambe opposée s’allonge et que le buste pivote.", 0.46)
        case .twist:
            (title, description, cadence) = ("Rotations russes", "Le buste assis pivote de gauche à droite, les mains jointes devant le sternum.", 0.42)
        case .obliqueCrunch:
            (title, description, cadence) = ("Crunch oblique", "Chaque épaule se rapproche alternativement du genou opposé.", 0.4)
        case .heelTap:
            (title, description, cadence) = ("Toucher de talons", "Le buste légèrement fléchi s’incline alternativement vers chaque talon.", 0.55)
        case .plank:
            (title, description, cadence) = ("Planche", "Le corps reste aligné des épaules aux chevilles, la respiration reste calme.", 0.16)
        case .sidePlank:
            (title, description, cadence) = ("Planche latérale", "Le corps reste aligné sur le côté, le bassin descend légèrement puis remonte.", 0.24)
        case .plankReach:
            (title, description, cadence) = ("Planche bras tendu", "Un bras s’allonge devant le corps pendant que le bassin reste stable.", 0.3)
        case .mountainClimber:
            (title, description, cadence) = ("Grimpeur", "Les genoux reviennent rapidement et alternativement sous la poitrine.", 0.68)
        case .hollowHold:
            (title, description, cadence) = ("Gainage creux", "Bras et jambes restent allongés au-dessus du tapis, le bas du dos plaqué au sol.", 0.16)
        case .deadBug:
            (title, description, cadence) = ("Dead bug", "Un bras et la jambe opposée s’allongent pendant que le tronc reste immobile.", 0.28)
        case .birdDog:
            (title, description, cadence) = ("Bird dog", "À quatre pattes, un bras et la jambe opposée s’allongent à l’horizontale.", 0.26)
        case .bearHold:
            (title, description, cadence) = ("Gainage de l’ours", "Les genoux restent décollés du sol et les appuis alternent doucement.", 0.3)
        case .seatedTuck:
            (title, description, cadence) = ("Genoux-poitrine assis", "Assis en appui sur les mains, les genoux se ramènent vers la poitrine puis les jambes s’allongent.", 0.34)
        case .bridgeMarch:
            (title, description, cadence) = ("Marche en pont", "Le bassin reste haut et immobile pendant qu’un genou se lève, puis l’autre.", 0.34)
        case .vSit:
            (title, description, cadence) = ("Maintien en V", "Le buste et les jambes s’éloignent puis reviennent autour d’un bassin stable.", 0.28)
        case .superman:
            (title, description, cadence) = ("Superman", "Allongé sur le ventre, les bras et les jambes se soulèvent sur une faible amplitude.", 0.24)
        case .bridge:
            (title, description, cadence) = ("Pont fessier", "Le bassin monte jusqu’à aligner épaules, hanches et genoux, puis redescend.", 0.28)
        case .squat:
            (title, description, cadence) = ("Squat", "Le bassin recule et descend jusqu’à ce que les cuisses approchent l’horizontale, puis remonte.", 0.3)
        case .rest:
            (title, description, cadence) = ("Récupération", "Le corps reste allongé et le thorax accompagne une respiration lente.", 0.12)
        }

        let framing = self.framing(for: motion)
        return MotionVisualMetadata(
            title: title,
            accessibilityDescription: description,
            cyclesPerSecond: cadence,
            cameraTarget: framing.target,
            cameraPosition: framing.position
        )
    }

    /// How a repetition is distributed across its cycle.
    static func tempo(for motion: MotionKind) -> MotionTempo {
        switch motion {
        case .crunch, .reverseCrunch, .toeReach, .hipRaise, .obliqueCrunch, .bridge, .squat:
            .controlled
        case .legRaise, .vSit, .superman, .sidePlank, .plankReach, .deadBug, .birdDog, .seatedTuck:
            .deliberate
        case .bridgeMarch:
            .controlled
        case .flutter, .scissors, .bicycle, .twist, .heelTap, .mountainClimber:
            .explosive
        case .plank, .hollowHold, .bearHold, .rest:
            .isometric
        }
    }

    /// Which muscles a movement loads, and how hard.
    static func load(for motion: MotionKind) -> MuscleLoad {
        switch motion {
        case .crunch:
            MuscleLoad(upperAbs: 1, lowerAbs: 0.45, obliques: 0.3, deepCore: 0.55, restingTone: 0.12)
        case .reverseCrunch:
            MuscleLoad(upperAbs: 0.4, lowerAbs: 1, obliques: 0.3, deepCore: 0.7, restingTone: 0.14)
        case .toeReach:
            MuscleLoad(upperAbs: 1, lowerAbs: 0.6, obliques: 0.32, deepCore: 0.62, restingTone: 0.18)
        case .legRaise:
            MuscleLoad(upperAbs: 0.35, lowerAbs: 1, obliques: 0.28, deepCore: 0.8, restingTone: 0.22)
        case .hipRaise:
            MuscleLoad(upperAbs: 0.35, lowerAbs: 1, obliques: 0.3, deepCore: 0.72, restingTone: 0.16)
        case .flutter:
            MuscleLoad(upperAbs: 0.3, lowerAbs: 1, obliques: 0.3, deepCore: 0.82, restingTone: 0.4, repetitionsPerCycle: 2)
        case .scissors:
            MuscleLoad(upperAbs: 0.28, lowerAbs: 1, obliques: 0.42, deepCore: 0.8, restingTone: 0.38, repetitionsPerCycle: 2)
        case .bicycle:
            MuscleLoad(upperAbs: 0.62, lowerAbs: 0.78, obliques: 1, deepCore: 0.6, restingTone: 0.24, alternatesSides: true)
        case .twist:
            MuscleLoad(upperAbs: 0.45, lowerAbs: 0.4, obliques: 1, deepCore: 0.62, restingTone: 0.28, alternatesSides: true)
        case .obliqueCrunch:
            MuscleLoad(upperAbs: 0.72, lowerAbs: 0.35, obliques: 1, deepCore: 0.5, restingTone: 0.16, alternatesSides: true)
        case .heelTap:
            MuscleLoad(upperAbs: 0.5, lowerAbs: 0.3, obliques: 1, deepCore: 0.45, restingTone: 0.22, alternatesSides: true)
        case .plank:
            MuscleLoad(upperAbs: 0.55, lowerAbs: 0.6, obliques: 0.5, deepCore: 1, restingTone: 0.78)
        case .sidePlank:
            MuscleLoad(upperAbs: 0.3, lowerAbs: 0.35, obliques: 1, deepCore: 0.85, restingTone: 0.7)
        case .plankReach:
            MuscleLoad(upperAbs: 0.45, lowerAbs: 0.5, obliques: 0.8, deepCore: 1, restingTone: 0.6, alternatesSides: true)
        case .mountainClimber:
            MuscleLoad(upperAbs: 0.42, lowerAbs: 0.95, obliques: 0.6, deepCore: 1, restingTone: 0.35, alternatesSides: true)
        case .hollowHold:
            MuscleLoad(upperAbs: 0.85, lowerAbs: 0.95, obliques: 0.5, deepCore: 1, restingTone: 0.82)
        case .deadBug:
            MuscleLoad(upperAbs: 0.4, lowerAbs: 0.7, obliques: 0.45, deepCore: 1, restingTone: 0.45, alternatesSides: true)
        case .birdDog:
            MuscleLoad(upperAbs: 0.25, lowerAbs: 0.35, obliques: 0.5, deepCore: 0.9, lowerBack: 1, restingTone: 0.45, alternatesSides: true)
        case .bearHold:
            MuscleLoad(upperAbs: 0.4, lowerAbs: 0.6, obliques: 0.5, deepCore: 1, restingTone: 0.72)
        case .vSit:
            MuscleLoad(upperAbs: 0.85, lowerAbs: 1, obliques: 0.45, deepCore: 0.9, restingTone: 0.42)
        case .seatedTuck:
            MuscleLoad(upperAbs: 0.6, lowerAbs: 1, obliques: 0.4, deepCore: 0.85, restingTone: 0.4)
        case .bridgeMarch:
            MuscleLoad(upperAbs: 0.2, lowerAbs: 0.6, obliques: 0.55, deepCore: 0.9, lowerBack: 1, restingTone: 0.5, alternatesSides: true)
        case .superman:
            MuscleLoad(upperAbs: 0.15, lowerAbs: 0.2, obliques: 0.3, deepCore: 0.6, lowerBack: 1, restingTone: 0.2)
        case .bridge:
            MuscleLoad(upperAbs: 0.2, lowerAbs: 0.5, obliques: 0.3, deepCore: 0.7, lowerBack: 0.9, restingTone: 0.15)
        case .squat:
            MuscleLoad(
                deepCore: 0.5, lowerBack: 0.4,
                glutes: 1, quadriceps: 1, hamstrings: 0.6, calves: 0.45,
                restingTone: 0.12
            )
        case .rest:
            MuscleLoad(upperAbs: 0.1, lowerAbs: 0.1, obliques: 0.08, deepCore: 0.14, restingTone: 0.9)
        }
    }

    /// The pose of the avatar at `phase` of the movement's cycle.
    static func pose(for motion: MotionKind, phase rawPhase: Float) -> BodyPose {
        let sketch = sketch(for: motion, phase: MotionTempo.wrap(rawPhase))
        let solved = PoseSolver.solve(sketch.pose)
        let anchored: BodyPose
        if let joint = sketch.anchor {
            anchored = PoseSolver.anchor(solved, joint: joint, to: sketch.pose[keyPath: joint])
        } else {
            anchored = solved
        }
        return PoseSolver.settle(anchored, groundLevel: groundLevel)
    }
}

// MARK: - Framing

private extension MotionLibrary {
    struct Framing {
        let target: SIMD3<Float>
        let position: SIMD3<Float>
    }

    /// Where the camera stands for each stance.
    ///
    /// The athlete lies along X and spans roughly 2.6 units, so the camera sits
    /// well back and mostly to the side: a near-side view keeps that length
    /// across the screen where it can be read, and a small offset toward the
    /// front keeps the abdominal wall — the part that matters — facing the
    /// viewer. Earlier framings sat at a steep three-quarter angle barely four
    /// units out, which cropped the legs and foreshortened everything else.
    static func framing(for motion: MotionKind) -> Framing {
        switch motion {
        case .twist, .vSit, .seatedTuck:
            Framing(target: SIMD3<Float>(0.15, 0.62, 0), position: SIMD3<Float>(0.95, 1.4, 5.1))
        case .plank, .sidePlank, .plankReach, .mountainClimber, .birdDog, .bearHold:
            // On all fours the athlete reaches further toward the head than any
            // other stance, so this framing sits back and re-centres to keep it in.
            Framing(target: SIMD3<Float>(0.05, 0.5, 0), position: SIMD3<Float>(0.85, 1.5, 5.8))
        case .squat:
            // Standing work is tall rather than long, so the camera comes in and
            // rises to meet it.
            Framing(target: SIMD3<Float>(0, 1.05, 0), position: SIMD3<Float>(0.6, 1.5, 4.6))
        case .bridge, .bridgeMarch:
            Framing(target: SIMD3<Float>(0.05, 0.5, 0), position: SIMD3<Float>(1.0, 1.6, 5.5))
        default:
            Framing(target: SIMD3<Float>(0.05, 0.45, 0), position: SIMD3<Float>(1.0, 1.6, 5.5))
        }
    }
}

// MARK: - Choreography

private extension MotionLibrary {
    /// A pose before it has been made anatomically rigid, plus the joint that
    /// must stay planted while the solver works.
    struct PoseSketch {
        var pose: BodyPose
        var anchor: KeyPath<BodyPose, SIMD3<Float>>?

        init(_ pose: BodyPose, anchor: KeyPath<BodyPose, SIMD3<Float>>? = nil) {
            self.pose = pose
            self.anchor = anchor
        }
    }

    static func sketch(for motion: MotionKind, phase: Float) -> PoseSketch {
        let tempo = tempo(for: motion)
        let effort = tempo.envelope(at: phase)
        let swing = MotionTempo.oscillation(at: phase, dwell: 0.3)
        let breath = MotionTempo.breath(at: phase)

        switch motion {
        case .crunch:
            var pose = supineBentKnees()
            curlTorso(&pose, amount: effort * 0.62)
            handsBehindHead(&pose)
            return PoseSketch(pose)

        case .reverseCrunch:
            var pose = supineBentKnees()
            tuckLegs(&pose, amount: effort)
            pose.pelvis.y += effort * 0.1
            return PoseSketch(pose, anchor: \.chest)

        case .toeReach:
            var pose = supineLegsRaised()
            curlTorso(&pose, amount: effort * 0.5)
            reachHands(&pose, toward: pose.leftAnkle, and: pose.rightAnkle, amount: 0.55 + effort * 0.35)
            return PoseSketch(pose)

        case .legRaise:
            var pose = supineStraight()
            setLegAngle(&pose, angle: mix(0.12, 1.32, t: effort))
            return PoseSketch(pose)

        case .hipRaise:
            var pose = supineBentKnees()
            tuckLegs(&pose, amount: effort * 0.85)
            pose.pelvis.y += effort * 0.14
            return PoseSketch(pose, anchor: \.chest)

        case .flutter:
            var pose = supineStraight()
            setLegAngle(&pose, angle: 0.22)
            pose.leftAnkle.y += swing * 0.2
            pose.rightAnkle.y -= swing * 0.2
            pose.leftKnee.y += swing * 0.09
            pose.rightKnee.y -= swing * 0.09
            return PoseSketch(pose)

        case .scissors:
            var pose = supineStraight()
            setLegAngle(&pose, angle: 0.28)
            pose.leftAnkle.z += swing * 0.24
            pose.rightAnkle.z -= swing * 0.24
            pose.leftKnee.z += swing * 0.12
            pose.rightKnee.z -= swing * 0.12
            return PoseSketch(pose)

        case .bicycle:
            var pose = supineBentKnees()
            pedalLegs(&pose, leftTuck: 0.5 + swing * 0.5)
            curlTorso(&pose, amount: 0.4)
            handsBehindHead(&pose)
            twistTorso(&pose, amount: -swing * 0.34)
            return PoseSketch(pose)

        case .twist:
            var pose = seated()
            // The hands are placed in front of the sternum *before* the twist so
            // the rotation carries them along with the shoulder girdle. Placing
            // them afterwards let them slide independently, and the hands ended
            // up turning against the shoulders.
            // Far enough from the shoulders that the elbows stay softly bent:
            // hands tucked in close fold the arms into a flail over the chest.
            let handCentre = pose.chest + SIMD3<Float>(0.5, -0.19, 0)
            pose.leftHand = handCentre + SIMD3<Float>(0, 0, 0.05)
            pose.rightHand = handCentre - SIMD3<Float>(0, 0, 0.05)
            pose.leftElbow = aimLimb(
                from: pose.leftShoulder,
                to: pose.leftHand,
                bend: SIMD3<Float>(-0.2, -1, 0.7)
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder,
                to: pose.rightHand,
                bend: SIMD3<Float>(-0.2, -1, -0.7)
            )
            twistTorso(&pose, amount: swing * 0.5)
            return PoseSketch(pose)

        case .obliqueCrunch:
            var pose = supineBentKnees()
            curlTorso(&pose, amount: 0.2 + abs(swing) * 0.4)
            handsBehindHead(&pose)
            twistTorso(&pose, amount: swing * 0.44)
            return PoseSketch(pose)

        case .heelTap:
            var pose = supineBentKnees()
            curlTorso(&pose, amount: 0.26)
            sideBend(&pose, amount: swing * 0.3)
            pose.leftHand = mix(pose.leftHand, pose.leftAnkle, t: max(swing, 0) * 0.55)
            pose.rightHand = mix(pose.rightHand, pose.rightAnkle, t: max(-swing, 0) * 0.55)
            return PoseSketch(pose)

        case .plank:
            var pose = forearmPlank()
            let ripple = breath * 0.012
            pose.chest.y += ripple
            pose.pelvis.y += ripple * 0.6
            return PoseSketch(pose)

        case .sidePlank:
            var pose = sidePlank()
            let drop = effort * 0.13
            pose.pelvis.y -= drop
            pose.leftHip.y -= drop
            pose.rightHip.y -= drop
            return PoseSketch(pose, anchor: \.leftElbow)

        case .plankReach:
            var pose = highPlank()
            let reach = abs(swing)
            if swing >= 0 {
                let target = SIMD3<Float>(-1.19, 0.92, 0.24)
                pose.leftElbow = mix(
                    pose.leftElbow,
                    aimLimb(from: pose.leftShoulder, to: target, bend: SIMD3<Float>(0, 0, 1)),
                    t: reach
                )
                pose.leftHand = mix(pose.leftHand, target, t: reach)
            } else {
                let target = SIMD3<Float>(-1.19, 0.92, -0.24)
                pose.rightElbow = mix(
                    pose.rightElbow,
                    aimLimb(from: pose.rightShoulder, to: target, bend: SIMD3<Float>(0, 0, -1)),
                    t: reach
                )
                pose.rightHand = mix(pose.rightHand, target, t: reach)
            }
            return PoseSketch(pose, anchor: \.rightHand)

        case .mountainClimber:
            var pose = highPlank()
            climbLegs(&pose, leftTuck: 0.5 + swing * 0.5)
            return PoseSketch(pose, anchor: \.leftHand)

        case .hollowHold:
            var pose = supineStraight()
            setLegAngle(&pose, angle: 0.3 + breath * 0.02)
            armsOverhead(&pose)
            curlTorso(&pose, amount: 0.2)
            return PoseSketch(pose)

        case .deadBug:
            var pose = supineTabletop()
            extendOpposites(&pose, leftLeg: swing >= 0, amount: abs(swing))
            return PoseSketch(pose)

        case .birdDog:
            var pose = quadruped()
            extendBirdDog(&pose, leftArm: swing >= 0, amount: abs(swing))
            return PoseSketch(pose)

        case .bearHold:
            var pose = quadruped()
            // Knees hover under the hips with the toes still planted. Simply
            // raising the quadruped's knees left the shins floating flat, which
            // read as nothing recognisable at all.
            let bearAnkle = SIMD3<Float>(0.56, 0.13, -0.17)
            let bearKnee = SIMD3<Float>(0.08, 0.3, -0.17)
            pose.leftAnkle = bearAnkle
            pose.rightAnkle = mirrored(bearAnkle)
            pose.leftKnee = bearKnee
            pose.rightKnee = mirrored(bearKnee)
            let lift = abs(swing) * 0.07
            if swing >= 0 {
                pose.leftHand.y += lift
                pose.leftElbow.y += lift * 0.5
            } else {
                pose.rightHand.y += lift
                pose.rightElbow.y += lift * 0.5
            }
            return PoseSketch(pose)

        case .vSit:
            var pose = seated()
            curlTorso(&pose, amount: -effort * 0.3)
            pose.leftAnkle = mix(pose.leftAnkle, SIMD3<Float>(1.06, 0.7, 0.16), t: effort)
            pose.rightAnkle = mix(pose.rightAnkle, SIMD3<Float>(1.06, 0.7, -0.16), t: effort)
            pose.leftKnee = mix(pose.leftKnee, SIMD3<Float>(0.55, 0.56, 0.17), t: effort)
            pose.rightKnee = mix(pose.rightKnee, SIMD3<Float>(0.55, 0.56, -0.17), t: effort)
            pose.leftHand = mix(pose.leftHand, SIMD3<Float>(0.44, 0.66, 0.2), t: effort)
            pose.rightHand = mix(pose.rightHand, SIMD3<Float>(0.44, 0.66, -0.2), t: effort)
            return PoseSketch(pose, anchor: \.pelvis)

        case .seatedTuck:
            var pose = seated()
            // Hands planted behind the hips: the whole point of the movement is
            // that the upper body is propped and only the legs travel.
            pose.leftHand = pose.pelvis + SIMD3<Float>(-0.34, -0.1, -0.26)
            pose.rightHand = pose.pelvis + SIMD3<Float>(-0.34, -0.1, 0.26)
            pose.leftElbow = aimLimb(
                from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(1, 0, -0.5)
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(1, 0, 0.5)
            )
            curlTorso(&pose, amount: -0.24)

            let tuckedAnkle = SIMD3<Float>(0.44, 0.62, -0.16)
            let openAnkle = SIMD3<Float>(1.12, 0.32, -0.16)
            let reach = 1 - effort
            pose.leftAnkle = mix(tuckedAnkle, openAnkle, t: reach)
            pose.rightAnkle = mix(mirrored(tuckedAnkle), mirrored(openAnkle), t: reach)
            pose.leftKnee = aimLimb(from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(0, 1, 0))
            pose.rightKnee = aimLimb(from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(0, 1, 0))
            return PoseSketch(pose, anchor: \.pelvis)

        case .bridgeMarch:
            var pose = supineBentKnees()
            // The bridge is already up and stays there; only a knee travels.
            pose.pelvis.y += 0.4
            let lift = abs(swing)
            if swing >= 0 {
                pose.leftKnee = mix(pose.leftKnee, SIMD3<Float>(0.24, 0.86, -0.17), t: lift)
                pose.leftAnkle = mix(pose.leftAnkle, SIMD3<Float>(0.62, 0.72, -0.17), t: lift)
            } else {
                pose.rightKnee = mix(pose.rightKnee, SIMD3<Float>(0.24, 0.86, 0.17), t: lift)
                pose.rightAnkle = mix(pose.rightAnkle, SIMD3<Float>(0.62, 0.72, 0.17), t: lift)
            }
            return PoseSketch(pose, anchor: \.chest)

        case .superman:
            var pose = prone()
            let rise = effort * 0.24
            pose.leftHand.y += rise
            pose.rightHand.y += rise
            pose.leftElbow.y += rise * 0.7
            pose.rightElbow.y += rise * 0.7
            pose.leftAnkle.y += rise * 0.8
            pose.rightAnkle.y += rise * 0.8
            pose.leftKnee.y += rise * 0.4
            pose.rightKnee.y += rise * 0.4
            pose.neck.y += rise * 0.4
            pose.head.y += rise * 0.5
            return PoseSketch(pose, anchor: \.pelvis)

        case .bridge:
            var pose = supineBentKnees()
            pose.pelvis.y += effort * 0.42
            return PoseSketch(pose, anchor: \.chest)

        case .squat:
            var pose = standing()
            let drop = effort * 0.44
            // Hips travel back as well as down — a squat that only sinks reads
            // as a knee bend and puts the load in the wrong place.
            pose.pelvis += SIMD3<Float>(-drop * 0.42, -drop, 0)
            pose.leftKnee = aimLimb(
                from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(1, 0, 0), offset: 0.2
            )
            pose.rightKnee = aimLimb(
                from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(1, 0, 0), offset: 0.2
            )
            curlTorso(&pose, amount: effort * 0.5)
            return PoseSketch(pose)

        case .rest:
            var pose = supineBentKnees()
            pose.chest.y += (breath + 1) * 0.014
            return PoseSketch(pose)
        }
    }
}

// MARK: - Base stances

private extension MotionLibrary {
    /// Lying on the back. The athlete's left is on the negative side: with the
    /// head toward -X and the belly up, that is which way round a person
    /// actually is, and getting it backwards pointed the body's whole facing
    /// into the mat — which is where the feet ended up pointing too.
    static func supineBentKnees() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-1.07, 0.256, 0),
            neck: SIMD3<Float>(-0.86, 0.227, 0),
            chest: SIMD3<Float>(-0.56, 0.212, 0),
            pelvis: SIMD3<Float>(0.02, 0.2, 0),
            leftShoulder: SIMD3<Float>(-0.56, 0.212, -0.27),
            rightShoulder: SIMD3<Float>(-0.56, 0.212, 0.27),
            leftElbow: SIMD3<Float>(-0.18, 0.18, -0.33),
            rightElbow: SIMD3<Float>(-0.18, 0.18, 0.33),
            leftHand: SIMD3<Float>(0.2, 0.15, -0.36),
            rightHand: SIMD3<Float>(0.2, 0.15, 0.36),
            leftHip: SIMD3<Float>(0.02, 0.2, -0.16),
            rightHip: SIMD3<Float>(0.02, 0.2, 0.16),
            leftKnee: SIMD3<Float>(0.38, 0.68, -0.17),
            rightKnee: SIMD3<Float>(0.38, 0.68, 0.17),
            leftAnkle: SIMD3<Float>(0.56, 0.13, -0.175),
            rightAnkle: SIMD3<Float>(0.56, 0.13, 0.175)
        )
    }

    static func supineStraight() -> BodyPose {
        var pose = supineBentKnees()
        pose.leftKnee = SIMD3<Float>(0.62, 0.19, -0.16)
        pose.rightKnee = SIMD3<Float>(0.62, 0.19, 0.16)
        pose.leftAnkle = SIMD3<Float>(1.16, 0.135, -0.16)
        pose.rightAnkle = SIMD3<Float>(1.16, 0.135, 0.16)
        return pose
    }

    static func supineLegsRaised() -> BodyPose {
        var pose = supineStraight()
        pose.leftKnee = SIMD3<Float>(0.06, 0.8, -0.16)
        pose.rightKnee = SIMD3<Float>(0.06, 0.8, 0.16)
        pose.leftAnkle = SIMD3<Float>(0.05, 1.35, -0.155)
        pose.rightAnkle = SIMD3<Float>(0.05, 1.35, 0.155)
        return pose
    }

    static func supineTabletop() -> BodyPose {
        var pose = supineBentKnees()
        pose.leftKnee = SIMD3<Float>(0.09, 0.8, -0.17)
        pose.rightKnee = SIMD3<Float>(0.09, 0.8, 0.17)
        pose.leftAnkle = SIMD3<Float>(0.67, 0.83, -0.17)
        pose.rightAnkle = SIMD3<Float>(0.67, 0.83, 0.17)
        pose.leftElbow = SIMD3<Float>(-0.54, 0.6, -0.27)
        pose.rightElbow = SIMD3<Float>(-0.54, 0.6, 0.27)
        pose.leftHand = SIMD3<Float>(-0.53, 0.94, -0.26)
        pose.rightHand = SIMD3<Float>(-0.53, 0.94, 0.26)
        return pose
    }

    static func highPlank() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-1.0, 0.87, 0),
            neck: SIMD3<Float>(-0.8, 0.9, 0),
            chest: SIMD3<Float>(-0.5, 0.86, 0),
            pelvis: SIMD3<Float>(0.04, 0.66, 0),
            leftShoulder: SIMD3<Float>(-0.5, 0.86, 0.27),
            rightShoulder: SIMD3<Float>(-0.5, 0.86, -0.27),
            leftElbow: SIMD3<Float>(-0.5, 0.5, 0.41),
            rightElbow: SIMD3<Float>(-0.5, 0.5, -0.41),
            leftHand: SIMD3<Float>(-0.5, 0.13, 0.27),
            rightHand: SIMD3<Float>(-0.5, 0.13, -0.27),
            leftHip: SIMD3<Float>(0.04, 0.66, 0.16),
            rightHip: SIMD3<Float>(0.04, 0.66, -0.16),
            leftKnee: SIMD3<Float>(0.6, 0.53, 0.16),
            rightKnee: SIMD3<Float>(0.6, 0.53, -0.16),
            leftAnkle: SIMD3<Float>(1.11, 0.18, 0.16),
            rightAnkle: SIMD3<Float>(1.11, 0.18, -0.16)
        )
    }

    static func forearmPlank() -> BodyPose {
        var pose = highPlank()
        pose.chest = SIMD3<Float>(-0.5, 0.51, 0)
        pose.neck = SIMD3<Float>(-0.8, 0.55, 0)
        pose.head = SIMD3<Float>(-1.0, 0.52, 0)
        pose.leftShoulder = SIMD3<Float>(-0.5, 0.51, 0.27)
        pose.rightShoulder = SIMD3<Float>(-0.5, 0.51, -0.27)
        pose.leftElbow = SIMD3<Float>(-0.5, 0.13, 0.27)
        pose.rightElbow = SIMD3<Float>(-0.5, 0.13, -0.27)
        pose.leftHand = SIMD3<Float>(-0.88, 0.13, 0.25)
        pose.rightHand = SIMD3<Float>(-0.88, 0.13, -0.25)
        pose.pelvis = SIMD3<Float>(0.06, 0.43, 0)
        pose.leftHip = SIMD3<Float>(0.06, 0.43, 0.16)
        pose.rightHip = SIMD3<Float>(0.06, 0.43, -0.16)
        pose.leftKnee = SIMD3<Float>(0.63, 0.32, 0.16)
        pose.rightKnee = SIMD3<Float>(0.63, 0.32, -0.16)
        pose.leftAnkle = SIMD3<Float>(1.18, 0.19, 0.16)
        pose.rightAnkle = SIMD3<Float>(1.18, 0.19, -0.16)
        return pose
    }

    static func quadruped() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-0.95, 0.88, 0),
            neck: SIMD3<Float>(-0.75, 0.92, 0),
            chest: SIMD3<Float>(-0.45, 0.86, 0),
            pelvis: SIMD3<Float>(0.1, 0.72, 0),
            leftShoulder: SIMD3<Float>(-0.45, 0.86, 0.27),
            rightShoulder: SIMD3<Float>(-0.45, 0.86, -0.27),
            leftElbow: SIMD3<Float>(-0.45, 0.5, 0.4),
            rightElbow: SIMD3<Float>(-0.45, 0.5, -0.4),
            leftHand: SIMD3<Float>(-0.45, 0.13, 0.25),
            rightHand: SIMD3<Float>(-0.45, 0.13, -0.25),
            leftHip: SIMD3<Float>(0.1, 0.72, 0.16),
            rightHip: SIMD3<Float>(0.1, 0.72, -0.16),
            leftKnee: SIMD3<Float>(0.16, 0.14, 0.17),
            rightKnee: SIMD3<Float>(0.16, 0.14, -0.17),
            leftAnkle: SIMD3<Float>(0.74, 0.15, 0.17),
            rightAnkle: SIMD3<Float>(0.74, 0.15, -0.17)
        )
    }

    static func seated() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-0.55, 1.15, 0),
            neck: SIMD3<Float>(-0.46, 0.96, 0),
            chest: SIMD3<Float>(-0.31, 0.7, 0),
            pelvis: SIMD3<Float>(0.02, 0.22, 0),
            leftShoulder: SIMD3<Float>(-0.31, 0.7, -0.27),
            rightShoulder: SIMD3<Float>(-0.31, 0.7, 0.27),
            leftElbow: SIMD3<Float>(0.02, 0.62, -0.24),
            rightElbow: SIMD3<Float>(0.02, 0.62, 0.24),
            leftHand: SIMD3<Float>(0.3, 0.6, -0.06),
            rightHand: SIMD3<Float>(0.3, 0.6, 0.06),
            leftHip: SIMD3<Float>(0.02, 0.22, -0.16),
            rightHip: SIMD3<Float>(0.02, 0.22, 0.16),
            leftKnee: SIMD3<Float>(0.45, 0.64, -0.17),
            rightKnee: SIMD3<Float>(0.45, 0.64, 0.17),
            leftAnkle: SIMD3<Float>(0.93, 0.31, -0.17),
            rightAnkle: SIMD3<Float>(0.93, 0.31, 0.17)
        )
    }

    /// Upright on both feet, facing along +X. The first stance in the library
    /// that stands up, which is what any lower-body movement needs.
    static func standing() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(0.02, 2.09, 0),
            neck: SIMD3<Float>(0.01, 1.96, 0),
            chest: SIMD3<Float>(0, 1.7, 0),
            pelvis: SIMD3<Float>(0, 1.12, 0),
            leftShoulder: SIMD3<Float>(0, 1.7, -0.25),
            rightShoulder: SIMD3<Float>(0, 1.7, 0.25),
            leftElbow: SIMD3<Float>(0.06, 1.33, -0.28),
            rightElbow: SIMD3<Float>(0.06, 1.33, 0.28),
            leftHand: SIMD3<Float>(0.12, 1.02, -0.3),
            rightHand: SIMD3<Float>(0.12, 1.02, 0.3),
            leftHip: SIMD3<Float>(0, 1.12, -0.155),
            rightHip: SIMD3<Float>(0, 1.12, 0.155),
            leftKnee: SIMD3<Float>(0.03, 0.6, -0.16),
            rightKnee: SIMD3<Float>(0.03, 0.6, 0.16),
            leftAnkle: SIMD3<Float>(0, 0.11, -0.16),
            rightAnkle: SIMD3<Float>(0, 0.11, 0.16)
        )
    }

    static func prone() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-1.07, 0.23, 0),
            neck: SIMD3<Float>(-0.86, 0.2, 0),
            chest: SIMD3<Float>(-0.56, 0.185, 0),
            pelvis: SIMD3<Float>(0.02, 0.19, 0),
            leftShoulder: SIMD3<Float>(-0.56, 0.185, 0.27),
            rightShoulder: SIMD3<Float>(-0.56, 0.185, -0.27),
            leftElbow: SIMD3<Float>(-0.93, 0.17, 0.22),
            rightElbow: SIMD3<Float>(-0.93, 0.17, -0.22),
            leftHand: SIMD3<Float>(-1.24, 0.15, 0.19),
            rightHand: SIMD3<Float>(-1.24, 0.15, -0.19),
            leftHip: SIMD3<Float>(0.02, 0.19, 0.16),
            rightHip: SIMD3<Float>(0.02, 0.19, -0.16),
            leftKnee: SIMD3<Float>(0.62, 0.17, 0.16),
            rightKnee: SIMD3<Float>(0.62, 0.17, -0.16),
            leftAnkle: SIMD3<Float>(1.16, 0.14, 0.16),
            rightAnkle: SIMD3<Float>(1.16, 0.14, -0.16)
        )
    }

    static func sidePlank() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-1.0, 0.68, 0.02),
            neck: SIMD3<Float>(-0.79, 0.66, 0.01),
            chest: SIMD3<Float>(-0.47, 0.62, 0),
            pelvis: SIMD3<Float>(0.11, 0.48, 0),
            leftShoulder: SIMD3<Float>(-0.47, 0.4, 0.16),
            rightShoulder: SIMD3<Float>(-0.47, 0.84, -0.16),
            leftElbow: SIMD3<Float>(-0.47, 0.13, 0.16),
            rightElbow: SIMD3<Float>(-0.44, 1.18, -0.16),
            leftHand: SIMD3<Float>(-0.85, 0.13, 0.14),
            rightHand: SIMD3<Float>(-0.4, 1.5, -0.16),
            leftHip: SIMD3<Float>(0.11, 0.4, 0.05),
            rightHip: SIMD3<Float>(0.11, 0.56, -0.05),
            leftKnee: SIMD3<Float>(0.66, 0.28, 0.04),
            rightKnee: SIMD3<Float>(0.66, 0.44, -0.04),
            leftAnkle: SIMD3<Float>(1.2, 0.13, 0.04),
            rightAnkle: SIMD3<Float>(1.2, 0.29, -0.04)
        )
    }
}

// MARK: - Pose operators

private extension MotionLibrary {
    /// Rotates the upper body around the hip axis. Positive amounts curl the
    /// ribs toward the pelvis, negative amounts open the chest away from it.
    ///
    /// The axis comes from the body's own frame rather than from the raw hip
    /// joints: taken from the joints, a stance lying on its back curls the
    /// opposite way to one lying face down.
    static func curlTorso(_ pose: inout BodyPose, amount: Float) {
        let axis = safeAxis(simd_cross(pose.up, pose.front), fallback: SIMD3<Float>(0, 0, 1))
        for joint in upperBodyJoints {
            pose[keyPath: joint] = rotate(pose[keyPath: joint], around: pose.pelvis, axis: axis, angle: amount)
        }
    }

    /// Rotates shoulders, arms and head around the spine.
    static func twistTorso(_ pose: inout BodyPose, amount: Float) {
        let axis = safeAxis(pose.chest - pose.pelvis, fallback: SIMD3<Float>(0, 1, 0))
        for joint in shoulderGirdleJoints {
            pose[keyPath: joint] = rotate(pose[keyPath: joint], around: pose.chest, axis: axis, angle: amount)
        }
    }

    /// Lateral flexion — the torso leans toward one side without rotating.
    /// Bending happens about the direction the body faces.
    static func sideBend(_ pose: inout BodyPose, amount: Float) {
        let axis = safeAxis(pose.front, fallback: SIMD3<Float>(0, 0, 1))
        for joint in upperBodyJoints {
            pose[keyPath: joint] = rotate(pose[keyPath: joint], around: pose.pelvis, axis: axis, angle: amount)
        }
    }

    static func handsBehindHead(_ pose: inout BodyPose) {
        let lateral = safeAxis(pose.leftShoulder - pose.rightShoulder, fallback: SIMD3<Float>(0, 0, 1))
        let back = safeAxis(pose.head - pose.chest, fallback: SIMD3<Float>(-1, 0, 0))
        pose.leftHand = pose.neck + lateral * 0.09 + back * 0.1
        pose.rightHand = pose.neck - lateral * 0.09 + back * 0.1
        pose.leftElbow = pose.leftShoulder + lateral * 0.16 + back * 0.16
        pose.rightElbow = pose.rightShoulder - lateral * 0.16 + back * 0.16
    }

    static func armsOverhead(_ pose: inout BodyPose) {
        let back = safeAxis(pose.head - pose.chest, fallback: SIMD3<Float>(-1, 0, 0))
        pose.leftHand = pose.leftShoulder + back * 0.7 + SIMD3<Float>(0, 0.18, -0.07)
        pose.rightHand = pose.rightShoulder + back * 0.7 + SIMD3<Float>(0, 0.18, 0.07)
        pose.leftElbow = pose.leftShoulder + back * 0.37 + SIMD3<Float>(0, 0.08, 0)
        pose.rightElbow = pose.rightShoulder + back * 0.37 + SIMD3<Float>(0, 0.08, 0)
    }

    static func reachHands(
        _ pose: inout BodyPose,
        toward leftTarget: SIMD3<Float>,
        and rightTarget: SIMD3<Float>,
        amount: Float
    ) {
        pose.leftHand = mix(pose.leftShoulder, leftTarget, t: amount)
        pose.rightHand = mix(pose.rightShoulder, rightTarget, t: amount)
        pose.leftElbow = mix(pose.leftShoulder, leftTarget, t: amount * 0.55) + SIMD3<Float>(0, 0, 0.05)
        pose.rightElbow = mix(pose.rightShoulder, rightTarget, t: amount * 0.55) - SIMD3<Float>(0, 0, 0.05)
    }

    /// Builds a pole hint that is guaranteed to sit off the limb axis.
    ///
    /// Interpolating two authored joint positions can walk the hint onto the
    /// line between root and target, and a hint on that line has no defined
    /// side — the solver then swings the elbow or knee across the limb between
    /// one frame and the next. Deriving the hint from an explicit bend
    /// direction keeps a stable side for the whole movement.
    ///
    /// Only the *direction* of `bend` matters: the solver decides how far the
    /// joint actually swings from the bone lengths.
    static func aimLimb(
        from root: SIMD3<Float>,
        to target: SIMD3<Float>,
        bend: SIMD3<Float>,
        offset: Float = 0.14
    ) -> SIMD3<Float> {
        let axis = safeAxis(target - root, fallback: SIMD3<Float>(1, 0, 0))
        var sideways = bend - axis * simd_dot(bend, axis)
        if simd_length(sideways) < 0.0001 {
            sideways = simd_cross(axis, SIMD3<Float>(0, 0, 1))
        }
        let direction = safeAxis(sideways, fallback: SIMD3<Float>(0, 1, 0))
        return root + axis * (simd_distance(root, target) * 0.5) + direction * offset
    }

    /// Places straight legs at `angle` radians above the mat.
    static func setLegAngle(_ pose: inout BodyPose, angle: Float) {
        let reach: Float = 1.14
        let direction = SIMD3<Float>(cos(angle), sin(angle), 0)
        // The knee hint sits just off the hip-to-ankle line so a near-straight
        // leg still bends the anatomically correct way.
        let bend = SIMD3<Float>(-direction.y, direction.x, 0)
        pose.leftAnkle = pose.leftHip + direction * reach
        pose.rightAnkle = pose.rightHip + direction * reach
        pose.leftKnee = pose.leftHip + direction * (reach * 0.5) + bend * 0.07
        pose.rightKnee = pose.rightHip + direction * (reach * 0.5) + bend * 0.07
    }

    static func tuckLegs(_ pose: inout BodyPose, amount: Float) {
        pose.leftKnee = mix(pose.leftKnee, SIMD3<Float>(0.02, 0.62, -0.17), t: amount)
        pose.rightKnee = mix(pose.rightKnee, SIMD3<Float>(0.02, 0.62, 0.17), t: amount)
        pose.leftAnkle = mix(pose.leftAnkle, SIMD3<Float>(0.3, 0.75, -0.17), t: amount)
        pose.rightAnkle = mix(pose.rightAnkle, SIMD3<Float>(0.3, 0.75, 0.17), t: amount)
    }

    static func pedalLegs(_ pose: inout BodyPose, leftTuck: Float) {
        let tuckedKnee = SIMD3<Float>(0.04, 0.66, -0.17)
        let tuckedAnkle = SIMD3<Float>(0.32, 0.72, -0.17)
        let openKnee = SIMD3<Float>(0.62, 0.4, -0.16)
        let openAnkle = SIMD3<Float>(1.15, 0.3, -0.16)

        pose.leftKnee = mix(openKnee, tuckedKnee, t: leftTuck)
        pose.leftAnkle = mix(openAnkle, tuckedAnkle, t: leftTuck)
        pose.rightKnee = mix(mirrored(tuckedKnee), mirrored(openKnee), t: leftTuck)
        pose.rightAnkle = mix(mirrored(tuckedAnkle), mirrored(openAnkle), t: leftTuck)
    }

    static func climbLegs(_ pose: inout BodyPose, leftTuck: Float) {
        let tuckedAnkle = SIMD3<Float>(0.42, 0.24, 0.18)
        let openAnkle = SIMD3<Float>(1.11, 0.18, 0.16)
        let lift = SIMD3<Float>(0, 1, 0)

        let leftTucked = aimLimb(from: pose.leftHip, to: tuckedAnkle, bend: lift)
        let leftOpen = aimLimb(from: pose.leftHip, to: openAnkle, bend: lift)
        let rightTucked = aimLimb(from: pose.rightHip, to: mirrored(tuckedAnkle), bend: lift)
        let rightOpen = aimLimb(from: pose.rightHip, to: mirrored(openAnkle), bend: lift)

        pose.leftKnee = mix(leftOpen, leftTucked, t: leftTuck)
        pose.leftAnkle = mix(openAnkle, tuckedAnkle, t: leftTuck)
        pose.rightKnee = mix(rightTucked, rightOpen, t: leftTuck)
        pose.rightAnkle = mix(mirrored(tuckedAnkle), mirrored(openAnkle), t: leftTuck)
    }

    static func extendOpposites(_ pose: inout BodyPose, leftLeg: Bool, amount: Float) {
        if leftLeg {
            pose.leftKnee = mix(pose.leftKnee, SIMD3<Float>(0.6, 0.36, -0.17), t: amount)
            pose.leftAnkle = mix(pose.leftAnkle, SIMD3<Float>(1.12, 0.24, -0.16), t: amount)
            pose.rightElbow = mix(pose.rightElbow, SIMD3<Float>(-0.94, 0.42, 0.24), t: amount)
            pose.rightHand = mix(pose.rightHand, SIMD3<Float>(-1.26, 0.24, 0.2), t: amount)
        } else {
            pose.rightKnee = mix(pose.rightKnee, SIMD3<Float>(0.6, 0.36, 0.17), t: amount)
            pose.rightAnkle = mix(pose.rightAnkle, SIMD3<Float>(1.12, 0.24, 0.16), t: amount)
            pose.leftElbow = mix(pose.leftElbow, SIMD3<Float>(-0.94, 0.42, -0.24), t: amount)
            pose.leftHand = mix(pose.leftHand, SIMD3<Float>(-1.26, 0.24, -0.2), t: amount)
        }
    }

    static func extendBirdDog(_ pose: inout BodyPose, leftArm: Bool, amount: Float) {
        let drop = SIMD3<Float>(0, -1, 0)
        if leftArm {
            let hand = SIMD3<Float>(-1.19, 0.9, 0.21)
            let ankle = SIMD3<Float>(1.24, 0.72, -0.16)
            pose.leftElbow = mix(
                pose.leftElbow,
                aimLimb(from: pose.leftShoulder, to: hand, bend: SIMD3<Float>(0, 0, 1)),
                t: amount
            )
            pose.leftHand = mix(pose.leftHand, hand, t: amount)
            pose.rightKnee = mix(
                pose.rightKnee,
                aimLimb(from: pose.rightHip, to: ankle, bend: drop),
                t: amount
            )
            pose.rightAnkle = mix(pose.rightAnkle, ankle, t: amount)
        } else {
            let hand = SIMD3<Float>(-1.19, 0.9, -0.21)
            let ankle = SIMD3<Float>(1.24, 0.72, 0.16)
            pose.rightElbow = mix(
                pose.rightElbow,
                aimLimb(from: pose.rightShoulder, to: hand, bend: SIMD3<Float>(0, 0, -1)),
                t: amount
            )
            pose.rightHand = mix(pose.rightHand, hand, t: amount)
            pose.leftKnee = mix(
                pose.leftKnee,
                aimLimb(from: pose.leftHip, to: ankle, bend: drop),
                t: amount
            )
            pose.leftAnkle = mix(pose.leftAnkle, ankle, t: amount)
        }
    }

    static let upperBodyJoints: [any WritableKeyPath<BodyPose, SIMD3<Float>> & Sendable] = [
        \.chest, \.neck, \.head,
        \.leftShoulder, \.rightShoulder,
        \.leftElbow, \.rightElbow,
        \.leftHand, \.rightHand
    ]

    static let shoulderGirdleJoints: [any WritableKeyPath<BodyPose, SIMD3<Float>> & Sendable] = [
        \.neck, \.head,
        \.leftShoulder, \.rightShoulder,
        \.leftElbow, \.rightElbow,
        \.leftHand, \.rightHand
    ]

    static func rotate(
        _ point: SIMD3<Float>,
        around pivot: SIMD3<Float>,
        axis: SIMD3<Float>,
        angle: Float
    ) -> SIMD3<Float> {
        guard angle.isFinite, abs(angle) > 0.00001 else { return point }
        return pivot + simd_quatf(angle: angle, axis: axis).act(point - pivot)
    }

    static func safeAxis(_ vector: SIMD3<Float>, fallback: SIMD3<Float>) -> SIMD3<Float> {
        let length = simd_length(vector)
        return length > 0.0001 ? vector / length : simd_normalize(fallback)
    }

    static func mirrored(_ point: SIMD3<Float>) -> SIMD3<Float> {
        SIMD3<Float>(point.x, point.y, -point.z)
    }

    static func mix(_ a: Float, _ b: Float, t: Float) -> Float {
        a + (b - a) * min(max(t, 0), 1)
    }

    static func mix(_ a: SIMD3<Float>, _ b: SIMD3<Float>, t: Float) -> SIMD3<Float> {
        a + (b - a) * min(max(t, 0), 1)
    }
}

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
        case .vSitExtension:
            (title, description, cadence) = ("Extension en V", "Depuis le V compact, le buste et les jambes s’éloignent en même temps puis reviennent.", 0.24)
        case .longLeverCrunch:
            (title, description, cadence) = ("Crunch bras tendus", "Les bras restent tendus près des oreilles pendant que le haut du dos décolle.", 0.3)
        case .sidePlankKnees:
            (title, description, cadence) = ("Planche latérale genoux", "En appui sur le genou du dessous, le bassin reste haut et la taille longue.", 0.14)
        case .sideCrunch:
            (title, description, cadence) = ("Crunch latéral", "Couché sur le côté, le buste se raccourcit vers la hanche puis redescend.", 0.32)
        case .hollowRock:
            (title, description, cadence) = ("Bascule creuse", "Le corps garde sa forme creuse et bascule d’un bloc sur le bas du dos.", 0.42)
        case .vUp:
            (title, description, cadence) = ("Relevé complet", "Le buste et les jambes tendues se rejoignent au-dessus du bassin, puis s’éloignent.", 0.28)
        case .singleLegBridge:
            (title, description, cadence) = ("Pont sur une jambe", "Une jambe reste tendue pendant que le bassin monte sur l’appui de l’autre.", 0.28)
        case .swimmer:
            (title, description, cadence) = ("Nageur", "Sur le ventre, le bras et la jambe opposés se lèvent puis changent.", 0.3)
        case .heelSlide:
            (title, description, cadence) = ("Glissé de talon", "Une jambe s’allonge au ras du sol puis revient, le dos toujours plaqué.", 0.26)
        case .reversePlank:
            (title, description, cadence) = ("Planche inversée", "Bassin haut et corps en ligne, poitrine ouverte vers le plafond.", 0.14)
        case .squat:
            (title, description, cadence) = ("Squat", "Le bassin recule et descend jusqu’à ce que les cuisses approchent l’horizontale, puis remonte.", 0.3)
        case .squatHold:
            (title, description, cadence) = ("Squat tenu", "Le bassin descend jusqu’à la position basse du squat et la position se tient.", 0.14)
        case .lunge:
            (title, description, cadence) = ("Fente arrière", "Un pas en arrière, le genou arrière descend vers le sol, puis retour debout — une jambe puis l’autre.", 0.24)
        case .lateralLunge:
            (title, description, cadence) = ("Fente latérale", "Un grand pas de côté, le bassin s’assoit sur la jambe qui plie, l’autre reste tendue.", 0.24)
        case .wallSit:
            (title, description, cadence) = ("Chaise", "Dos droit et cuisses à l’horizontale, la position se tient sans bouger.", 0.14)
        case .calfRaise:
            (title, description, cadence) = ("Mollets debout", "Les talons montent puis redescendent lentement sous contrôle.", 0.5)
        case .goodMorning:
            (title, description, cadence) = ("Good morning", "Mains derrière la tête, le buste bascule vers l’avant depuis les hanches, dos plat.", 0.28)
        case .donkeyKick:
            (title, description, cadence) = ("Donkey kick", "À quatre pattes, un talon pousse vers le plafond puis revient — une jambe puis l’autre.", 0.32)
        case .pushUp:
            (title, description, cadence) = ("Pompes", "Le corps descend d’un bloc jusqu’à ce que la poitrine frôle le sol, puis repousse.", 0.32)
        case .kneePushUp:
            (title, description, cadence) = ("Pompes genoux", "Mêmes pompes, appui sur les genoux : le levier est plus court, le mouvement identique.", 0.34)
        case .wallPushUp:
            (title, description, cadence) = ("Pompes au mur", "Debout face au mur, le corps bascule d’un bloc vers les mains puis repousse.", 0.36)
        case .pikePushUp:
            (title, description, cadence) = ("Pompes piquées", "Bassin haut, la tête descend entre les mains puis remonte.", 0.3)
        case .floorDip:
            (title, description, cadence) = ("Dips au sol", "Mains derrière le bassin, les coudes plient pour descendre le bassin puis le repoussent.", 0.34)
        case .proneRow:
            (title, description, cadence) = ("Tirage au sol", "Allongé sur le ventre, les bras tirent vers l’arrière en rapprochant les omoplates.", 0.32)
        case .plankUpDown:
            (title, description, cadence) = ("Planche montée-descente", "Un avant-bras se déroule en bras tendu puis revient, sans que le bassin bouge.", 0.28)
        case .squatThrust:
            (title, description, cadence) = ("Squat thrust", "Mains au sol, les pieds partent en planche puis reviennent sous le buste, sans saut.", 0.2)
        case .burpee:
            (title, description, cadence) = ("Burpee", "Debout, mains au sol, planche, pompe, retour des pieds et redressement.", 0.16)
        case .jumpingJack:
            (title, description, cadence) = ("Jumping jack", "Les jambes s’écartent pendant que les bras montent sur les côtés, en rythme.", 0.62)
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
        case .crunch, .reverseCrunch, .toeReach, .hipRaise, .obliqueCrunch, .bridge, .longLeverCrunch:
            .controlled
        case .legRaise, .vSit, .vSitExtension, .superman, .sidePlank, .plankReach, .deadBug, .birdDog, .seatedTuck:
            .deliberate
        case .sidePlankKnees, .reversePlank:
            .isometric
        case .sideCrunch, .vUp, .singleLegBridge, .heelSlide:
            .controlled
        case .swimmer:
            .deliberate
        case .hollowRock:
            .explosive
        case .bridgeMarch:
            .controlled
        case .flutter, .scissors, .bicycle, .twist, .heelTap, .mountainClimber:
            .explosive
        case .squat, .lunge, .lateralLunge, .goodMorning, .pushUp, .kneePushUp,
             .wallPushUp, .pikePushUp, .floorDip, .proneRow, .plankUpDown,
             .squatThrust, .burpee:
            .controlled
        case .donkeyKick:
            .deliberate
        case .calfRaise, .jumpingJack:
            .explosive
        case .wallSit, .squatHold:
            .isometric
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
        case .vSitExtension:
            MuscleLoad(upperAbs: 0.9, lowerAbs: 1, obliques: 0.45, deepCore: 1, restingTone: 0.45)
        case .longLeverCrunch:
            MuscleLoad(upperAbs: 1, lowerAbs: 0.5, obliques: 0.3, deepCore: 0.7, restingTone: 0.14)
        case .seatedTuck:
            MuscleLoad(upperAbs: 0.6, lowerAbs: 1, obliques: 0.4, deepCore: 0.85, restingTone: 0.4)
        case .bridgeMarch:
            MuscleLoad(upperAbs: 0.2, lowerAbs: 0.6, obliques: 0.55, deepCore: 0.9, lowerBack: 1, restingTone: 0.5, alternatesSides: true)
        case .superman:
            MuscleLoad(upperAbs: 0.15, lowerAbs: 0.2, obliques: 0.3, deepCore: 0.6, lowerBack: 1,
                       restingTone: 0.2)
        case .bridge:
            MuscleLoad(upperAbs: 0.2, lowerAbs: 0.5, obliques: 0.3, deepCore: 0.7, lowerBack: 1,
                       restingTone: 0.15)
        case .sidePlankKnees:
            MuscleLoad(upperAbs: 0.3, lowerAbs: 0.4, obliques: 1, deepCore: 0.9, restingTone: 0.8)
        case .sideCrunch:
            MuscleLoad(upperAbs: 0.5, lowerAbs: 0.3, obliques: 1, deepCore: 0.5, restingTone: 0.2)
        case .hollowRock:
            MuscleLoad(upperAbs: 0.9, lowerAbs: 1, obliques: 0.5, deepCore: 1, restingTone: 0.6)
        case .vUp:
            MuscleLoad(upperAbs: 1, lowerAbs: 1, obliques: 0.4, deepCore: 0.85, restingTone: 0.2)
        case .singleLegBridge:
            MuscleLoad(upperAbs: 0.2, lowerAbs: 0.5, obliques: 0.5, deepCore: 0.85, lowerBack: 1, restingTone: 0.3)
        case .swimmer:
            MuscleLoad(upperAbs: 0.15, lowerAbs: 0.25, obliques: 0.4, deepCore: 0.7, lowerBack: 1, restingTone: 0.3, alternatesSides: true)
        case .heelSlide:
            MuscleLoad(upperAbs: 0.3, lowerAbs: 0.85, obliques: 0.35, deepCore: 1, restingTone: 0.4, alternatesSides: true)
        case .reversePlank:
            MuscleLoad(upperAbs: 0.2, lowerAbs: 0.3, obliques: 0.4, deepCore: 0.8, lowerBack: 1, restingTone: 0.85)
        case .squat:
            MuscleLoad(
                deepCore: 0.5, lowerBack: 0.4,
                glutes: 1, quadriceps: 1, hamstrings: 0.6, calves: 0.45,
                restingTone: 0.12
            )
        case .lunge:
            MuscleLoad(
                deepCore: 0.55, lowerBack: 0.35,
                glutes: 1, quadriceps: 1, hamstrings: 0.7, calves: 0.5,
                restingTone: 0.14, alternatesSides: true
            )
        case .lateralLunge:
            MuscleLoad(
                obliques: 0.4, deepCore: 0.5, lowerBack: 0.35,
                glutes: 1, quadriceps: 0.9, hamstrings: 0.6, calves: 0.3,
                restingTone: 0.14, alternatesSides: true
            )
        case .wallSit:
            MuscleLoad(
                deepCore: 0.5, glutes: 0.75, quadriceps: 1, calves: 0.4,
                restingTone: 0.85
            )
        case .squatHold:
            MuscleLoad(
                deepCore: 0.55, lowerBack: 0.45,
                glutes: 0.9, quadriceps: 1, hamstrings: 0.5, calves: 0.5,
                restingTone: 0.86
            )
        case .calfRaise:
            MuscleLoad(deepCore: 0.25, quadriceps: 0.3, calves: 1, restingTone: 0.2)
        case .goodMorning:
            MuscleLoad(
                deepCore: 0.5, lowerBack: 0.9,
                glutes: 0.9, hamstrings: 1,
                restingTone: 0.22
            )
        case .donkeyKick:
            MuscleLoad(
                deepCore: 0.55, lowerBack: 0.5,
                glutes: 1, hamstrings: 0.7,
                restingTone: 0.2, alternatesSides: true
            )
        case .pushUp:
            MuscleLoad(
                upperAbs: 0.35, deepCore: 0.8,
                chest: 1, shoulders: 0.8, arms: 0.85, upperBack: 0.4,
                restingTone: 0.2
            )
        case .kneePushUp:
            MuscleLoad(
                upperAbs: 0.3, deepCore: 0.6,
                chest: 1, shoulders: 0.7, arms: 0.8, upperBack: 0.35,
                restingTone: 0.2
            )
        case .wallPushUp:
            MuscleLoad(
                deepCore: 0.35,
                chest: 0.85, shoulders: 0.6, arms: 0.7, upperBack: 0.3,
                restingTone: 0.16
            )
        case .pikePushUp:
            MuscleLoad(
                deepCore: 0.6,
                chest: 0.5, shoulders: 1, arms: 0.85, upperBack: 0.6,
                restingTone: 0.2
            )
        case .floorDip:
            MuscleLoad(
                deepCore: 0.4,
                chest: 0.5, shoulders: 0.75, arms: 1, upperBack: 0.35,
                restingTone: 0.2
            )
        case .proneRow:
            MuscleLoad(
                deepCore: 0.35, lowerBack: 0.6,
                shoulders: 0.8, arms: 0.5, upperBack: 1,
                restingTone: 0.24
            )
        case .plankUpDown:
            MuscleLoad(
                upperAbs: 0.4, lowerAbs: 0.45, obliques: 0.55, deepCore: 1,
                chest: 0.7, shoulders: 0.8, arms: 0.7,
                restingTone: 0.4, alternatesSides: true
            )
        case .squatThrust:
            MuscleLoad(
                upperAbs: 0.3, lowerAbs: 0.6, deepCore: 0.85,
                glutes: 0.8, quadriceps: 0.9, calves: 0.5,
                chest: 0.4, shoulders: 0.6, arms: 0.4,
                restingTone: 0.18
            )
        case .burpee:
            MuscleLoad(
                upperAbs: 0.35, lowerAbs: 0.6, deepCore: 0.85,
                glutes: 0.9, quadriceps: 1, hamstrings: 0.5, calves: 0.7,
                chest: 0.8, shoulders: 0.8, arms: 0.7,
                restingTone: 0.18
            )
        case .jumpingJack:
            MuscleLoad(
                deepCore: 0.3,
                glutes: 0.4, quadriceps: 0.5, calves: 0.9,
                shoulders: 0.85, arms: 0.3, upperBack: 0.5,
                restingTone: 0.2
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
        case .twist, .vSit, .vSitExtension, .seatedTuck:
            Framing(target: SIMD3<Float>(0.15, 0.62, 0), position: SIMD3<Float>(0.95, 1.4, 5.1))
        case .plank, .sidePlank, .plankReach, .mountainClimber, .birdDog, .bearHold:
            // On all fours the athlete reaches further toward the head than any
            // other stance, so this framing sits back and re-centres to keep it in.
            Framing(target: SIMD3<Float>(0.05, 0.5, 0), position: SIMD3<Float>(0.85, 1.5, 5.8))
        case .bridge, .bridgeMarch:
            Framing(target: SIMD3<Float>(0.05, 0.5, 0), position: SIMD3<Float>(1.0, 1.6, 5.5))
        case .squat, .squatHold, .lunge, .wallSit, .calfRaise, .goodMorning, .wallPushUp:
            // Standing work is tall rather than long, so the camera comes in and
            // rises to meet it.
            Framing(target: SIMD3<Float>(0, 1.05, 0), position: SIMD3<Float>(0.6, 1.5, 4.6))
        case .lateralLunge, .jumpingJack:
            // These two happen across the body rather than along it: a side view
            // shows a jumping jack as someone standing still with their arms
            // moving. Filmed from the front, the step and the spread are the
            // movement.
            Framing(target: SIMD3<Float>(0, 1.05, 0), position: SIMD3<Float>(5.0, 1.5, 0.7))
        case .squatThrust, .burpee:
            // These visit both extremes inside one repetition — upright and flat
            // on the mat — so the frame has to hold the union of the two.
            Framing(target: SIMD3<Float>(0.02, 0.9, 0), position: SIMD3<Float>(0.7, 1.7, 6.3))
        case .pushUp, .kneePushUp, .pikePushUp, .plankUpDown:
            Framing(target: SIMD3<Float>(0.1, 0.5, 0), position: SIMD3<Float>(0.9, 1.5, 5.6))
        case .donkeyKick:
            Framing(target: SIMD3<Float>(0.08, 0.55, 0), position: SIMD3<Float>(0.85, 1.5, 5.8))
        case .floorDip:
            Framing(target: SIMD3<Float>(0.05, 0.55, 0), position: SIMD3<Float>(0.95, 1.4, 5.2))
        default:
            Framing(target: SIMD3<Float>(0.05, 0.45, 0), position: SIMD3<Float>(1.0, 1.6, 5.5))
        }
    }
}

// MARK: - Choreography

// Internal rather than private so tests can inspect the authored pose. The
// solver rescales bones to canonical length, which quietly repairs a sketch
// that moved one joint without the joints attached to it — the mistake only
// shows up before that repair.
extension MotionLibrary {
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
            armsCrossedOnChest(&pose)
            return PoseSketch(pose)

        case .reverseCrunch:
            var pose = supineBentKnees()
            tuckLegs(&pose, amount: effort)
            moveHips(&pose, by: SIMD3<Float>(0, effort * 0.1, 0), carryingTorso: false)
            return PoseSketch(pose, anchor: \.chest)

        case .toeReach:
            var pose = supineLegsRaised()
            // Legs tip slightly toward the head so the reaching arms are not
            // parallel to them; parallel, the two merged into one shape.
            setLegAngle(&pose, angle: 1.28)
            curlTorso(&pose, amount: effort * 0.52)
            reachHands(
                &pose,
                toward: pose.leftAnkle - SIMD3<Float>(0, 0.16, 0),
                and: pose.rightAnkle - SIMD3<Float>(0, 0.16, 0),
                amount: 0.5 + effort * 0.34
            )
            return PoseSketch(pose)

        case .legRaise:
            var pose = supineStraight()
            setLegAngle(&pose, angle: mix(0.12, 1.32, t: effort))
            return PoseSketch(pose)

        case .hipRaise:
            var pose = supineBentKnees()
            tuckLegs(&pose, amount: effort * 0.85)
            moveHips(&pose, by: SIMD3<Float>(0, effort * 0.14, 0), carryingTorso: false)
            return PoseSketch(pose, anchor: \.chest)

        case .flutter:
            var pose = supineStraight()
            tuckHandsUnderSeat(&pose)
            setLegAngle(&pose, angle: 0.22)
            pose.leftAnkle.y += swing * 0.34
            pose.rightAnkle.y -= swing * 0.34
            pose.leftKnee.y += swing * 0.15
            pose.rightKnee.y -= swing * 0.15
            return PoseSketch(pose)

        case .scissors:
            var pose = supineStraight()
            tuckHandsUnderSeat(&pose)
            setLegAngle(&pose, angle: 0.3)
            pose.leftAnkle.z += swing * 0.42
            pose.rightAnkle.z -= swing * 0.42
            pose.leftAnkle.y += swing * 0.08
            pose.rightAnkle.y -= swing * 0.08
            pose.leftKnee.z += swing * 0.2
            pose.rightKnee.z -= swing * 0.2
            return PoseSketch(pose)

        case .bicycle:
            var pose = supineBentKnees()
            pedalLegs(&pose, leftTuck: 0.5 + swing * 0.5)
            curlTorso(&pose, amount: 0.4)
            armsCrossedOnChest(&pose)
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
            twistTorso(&pose, amount: swing * 0.78)
            return PoseSketch(pose)

        case .obliqueCrunch:
            var pose = supineBentKnees()
            curlTorso(&pose, amount: 0.2 + abs(swing) * 0.4)
            armsCrossedOnChest(&pose)
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
            moveHips(&pose, by: SIMD3<Float>(0, ripple * 0.6, 0), carryingTorso: false)
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
            let bearAnkle = SIMD3<Float>(0.60, 0.13, -0.17)
            let bearKnee = SIMD3<Float>(0.13, 0.25, -0.17)
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
                from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(-1, 0.2, -0.5)
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(-1, 0.2, 0.5)
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
            moveHips(&pose, by: SIMD3<Float>(0, 0.4, 0), carryingTorso: false)
            plantFeet(&pose)
            let lift = abs(swing)
            if swing >= 0 {
                pose.leftKnee = mix(pose.leftKnee, SIMD3<Float>(0.24, 0.86, -0.17), t: lift)
                pose.leftAnkle = mix(pose.leftAnkle, SIMD3<Float>(0.62, 0.72, -0.17), t: lift)
            } else {
                pose.rightKnee = mix(pose.rightKnee, SIMD3<Float>(0.24, 0.86, 0.17), t: lift)
                pose.rightAnkle = mix(pose.rightAnkle, SIMD3<Float>(0.62, 0.72, 0.17), t: lift)
            }
            return PoseSketch(pose, anchor: \.chest)

        case .vSitExtension:
            var pose = seated()
            // Compact to long: buste and legs open together, which is what
            // separates this from simply holding the V.
            let open = effort
            curlTorso(&pose, amount: -open * 0.46)
            pose.leftAnkle = mix(SIMD3<Float>(0.72, 0.72, -0.16), SIMD3<Float>(1.12, 0.5, -0.16), t: open)
            pose.rightAnkle = mix(SIMD3<Float>(0.72, 0.72, 0.16), SIMD3<Float>(1.12, 0.5, 0.16), t: open)
            pose.leftKnee = aimLimb(from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(0, 1, 0))
            pose.rightKnee = aimLimb(from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(0, 1, 0))
            reachHands(
                &pose,
                toward: pose.leftKnee,
                and: pose.rightKnee,
                amount: 0.75
            )
            return PoseSketch(pose, anchor: \.pelvis)

        case .longLeverCrunch:
            var pose = supineBentKnees()
            // Arms stay locked beside the ears through the whole repetition —
            // that long lever is the entire point of the variation.
            armsOverhead(&pose)
            curlTorso(&pose, amount: effort * 0.56)
            return PoseSketch(pose)

        case .superman:
            var pose = prone()
            // Lying flat, a small lift reads as no lift at all — the whole
            // movement disappeared into a horizontal line. The arch is now
            // unmistakable, and the chest lifts with the arms.
            let rise = effort * 0.42
            pose.leftHand.y += rise
            pose.rightHand.y += rise
            pose.leftElbow.y += rise * 0.72
            pose.rightElbow.y += rise * 0.72
            pose.leftAnkle.y += rise * 0.92
            pose.rightAnkle.y += rise * 0.92
            pose.leftKnee.y += rise * 0.45
            pose.rightKnee.y += rise * 0.45
            pose.chest.y += rise * 0.34
            pose.neck.y += rise * 0.52
            pose.head.y += rise * 0.62
            // Hands wide of the head rather than in front of it: run together
            // and the arms, head and mat merged into one flat white bar with
            // nothing in it to read as a lift.
            pose.leftHand.z = 0.31
            pose.rightHand.z = -0.31
            pose.leftElbow.z = 0.27
            pose.rightElbow.z = -0.27
            // And turned toward the viewer, because side-on a prone athlete is
            // a horizontal bar: the lift happens along the one axis the profile
            // compresses hardest. A three-quarter angle gives the arch somewhere
            // to go without giving this movement its own camera.
            yaw(&pose, by: 0.62)
            return PoseSketch(pose, anchor: \.pelvis)

        case .bridge:
            var pose = supineBentKnees()
            moveHips(&pose, by: SIMD3<Float>(0, effort * 0.42, 0), carryingTorso: false)
            // The feet stay planted, so the thigh has to rotate to follow the
            // hips. Left un-aimed it stretches instead and drags the foot up.
            plantFeet(&pose)
            return PoseSketch(pose, anchor: \.chest)

        case .sidePlankKnees:
            var pose = sidePlank()
            // Supported on the underneath knee rather than the foot, which is
            // the regression that makes a side plank reachable for a beginner.
            let settle = breath * 0.012
            pose.leftKnee = SIMD3<Float>(0.52, 0.14, 0.06)
            pose.rightKnee = SIMD3<Float>(0.52, 0.30, -0.06)
            pose.leftAnkle = SIMD3<Float>(0.86, 0.42, 0.06)
            pose.rightAnkle = SIMD3<Float>(0.86, 0.58, -0.06)
            // Shorter lever, so the hips sit a little lower than the full plank.
            moveHips(&pose, by: SIMD3<Float>(-0.06, -0.05 + settle, 0), carryingTorso: true)
            return PoseSketch(pose)

        case .sideCrunch:
            var pose = sideLying()
            // The trunk shortens toward the hip it is lying on. Bending about
            // the axis the body faces is what makes it lateral rather than a
            // plain curl.
            sideBend(&pose, amount: -effort * 0.42)
            pose.leftHand = pose.head + SIMD3<Float>(-0.16, -0.04, 0.06)
            pose.rightHand = pose.head + SIMD3<Float>(-0.12, 0.02, -0.12)
            pose.leftElbow = aimLimb(
                from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(0.4, -1, 0)
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(0.4, 1, 0)
            )
            // Turned toward the viewer: a side bend happens in the plane a
            // profile compresses hardest, so side-on the whole movement is a
            // flat line. Same reason the superman is turned.
            yaw(&pose, by: 0.7)
            return PoseSketch(pose)

        case .hollowRock:
            var pose = supineStraight()
            // The shape never changes — that is the whole point. It is the
            // shape that rocks, about a point under the low back.
            curlTorso(&pose, amount: 0.34)
            pose.leftHand = SIMD3<Float>(-1.22, 0.52, -0.3)
            pose.rightHand = SIMD3<Float>(-1.22, 0.52, 0.3)
            pose.leftElbow = aimLimb(
                from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(0, 1, -0.4)
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(0, 1, 0.4)
            )
            pose.leftAnkle = SIMD3<Float>(1.24, 0.5, -0.16)
            pose.rightAnkle = SIMD3<Float>(1.24, 0.5, 0.16)
            pose.leftKnee = aimLimb(from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(0, 1, 0))
            pose.rightKnee = aimLimb(from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(0, 1, 0))

            let rockAxis = safeAxis(pose.leftHip - pose.rightHip, fallback: SIMD3<Float>(0, 0, 1))
            let rock = swing * 0.2
            for joint in allJoints {
                pose[keyPath: joint] = rotate(
                    pose[keyPath: joint], around: pose.pelvis, axis: rockAxis, angle: rock
                )
            }
            return PoseSketch(pose, anchor: \.pelvis)

        case .vUp:
            var pose = supineStraight()
            // Legs and torso close on each other at the same time; a v-up that
            // lifts only one end is a leg raise or a crunch.
            let fold = effort * 0.9
            curlTorso(&pose, amount: fold * 0.62)
            pose.leftAnkle = mix(
                SIMD3<Float>(1.16, 0.135, -0.16), SIMD3<Float>(0.26, 1.16, -0.16), t: fold
            )
            pose.rightAnkle = mix(
                SIMD3<Float>(1.16, 0.135, 0.16), SIMD3<Float>(0.26, 1.16, 0.16), t: fold
            )
            pose.leftKnee = aimLimb(
                from: pose.leftHip, to: pose.leftAnkle,
                bend: sagittalBend(from: pose.leftHip, to: pose.leftAnkle)
            )
            pose.rightKnee = aimLimb(
                from: pose.rightHip, to: pose.rightAnkle,
                bend: sagittalBend(from: pose.rightHip, to: pose.rightAnkle)
            )
            // Hands reach for the ankles, so the two ends meet somewhere.
            // Overhead at rest, not tucked at the shoulder: at 0.08 from the
            // joint the arm has no direction to speak of, and the solver picks
            // a different one every frame.
            pose.leftHand = mix(
                SIMD3<Float>(-1.2, 0.16, -0.3), SIMD3<Float>(0.16, 0.92, -0.24), t: fold
            )
            pose.rightHand = mix(
                SIMD3<Float>(-1.2, 0.16, 0.3), SIMD3<Float>(0.16, 0.92, 0.24), t: fold
            )
            pose.leftElbow = aimLimb(
                from: pose.leftShoulder, to: pose.leftHand,
                bend: sagittalBend(from: pose.leftShoulder, to: pose.leftHand, sign: -1)
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder, to: pose.rightHand,
                bend: sagittalBend(from: pose.rightShoulder, to: pose.rightHand, sign: -1)
            )
            return PoseSketch(pose, anchor: \.pelvis)

        case .singleLegBridge:
            var pose = supineBentKnees()
            // One foot planted, the other leg carried straight in line with the
            // trunk so the working hip has nothing to share the load with.
            pose.rightKnee = SIMD3<Float>(0.42, 0.46, 0.17)
            pose.rightAnkle = SIMD3<Float>(0.92, 0.62, 0.17)
            moveHips(&pose, by: SIMD3<Float>(0, effort * 0.4, 0), carryingTorso: false)
            pose.leftKnee = aimLimb(
                from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(0, 1, 0), offset: 0.2
            )
            pose.rightKnee = aimLimb(
                from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(0, 1, 0), offset: 0.2
            )
            return PoseSketch(pose, anchor: \.chest)

        case .swimmer:
            var pose = prone()
            // Opposite arm and leg, taking turns. Small amplitude, long line.
            let reach = abs(swing) * 0.42
            if swing >= 0 {
                pose.leftHand.y += reach
                pose.leftElbow.y += reach * 0.6
                pose.rightAnkle.y += reach * 0.9
                pose.rightKnee.y += reach * 0.4
            } else {
                pose.rightHand.y += reach
                pose.rightElbow.y += reach * 0.6
                pose.leftAnkle.y += reach * 0.9
                pose.leftKnee.y += reach * 0.4
            }
            pose.chest.y += reach * 0.22
            pose.neck.y += reach * 0.34
            pose.head.y += reach * 0.4
            yaw(&pose, by: 0.78)
            return PoseSketch(pose, anchor: \.pelvis)

        case .heelSlide:
            var pose = supineTabletop()
            // One leg straightens along the mat and comes back. The whole test
            // is whether the lower back stays down while it does.
            let slide = abs(swing)
            let folded = SIMD3<Float>(0.09, 0.8, -0.17)
            let long = SIMD3<Float>(0.58, 0.2, -0.17)
            let foldedAnkle = SIMD3<Float>(0.67, 0.83, -0.17)
            let longAnkle = SIMD3<Float>(1.12, 0.14, -0.17)
            if swing >= 0 {
                pose.leftKnee = mix(folded, long, t: slide)
                pose.leftAnkle = mix(foldedAnkle, longAnkle, t: slide)
            } else {
                pose.rightKnee = mirrored(mix(folded, long, t: slide))
                pose.rightAnkle = mirrored(mix(foldedAnkle, longAnkle, t: slide))
            }
            return PoseSketch(pose)

        case .reversePlank:
            var pose = seated()
            // Face up, hips lifted into line between the hands and the heels.
            let settle = breath * 0.012
            pose.pelvis = SIMD3<Float>(0.2, 0.62 + settle, 0)
            pose.leftHip = pose.pelvis + SIMD3<Float>(0, 0, -0.155)
            pose.rightHip = pose.pelvis + SIMD3<Float>(0, 0, 0.155)
            pose.chest = SIMD3<Float>(-0.36, 0.7 + settle, 0)
            pose.neck = SIMD3<Float>(-0.62, 0.76 + settle, 0)
            pose.head = SIMD3<Float>(-0.74, 0.79 + settle, 0)
            pose.leftShoulder = pose.chest + SIMD3<Float>(0, 0, -0.25)
            pose.rightShoulder = pose.chest + SIMD3<Float>(0, 0, 0.25)
            pose.leftHand = SIMD3<Float>(-0.86, 0.13, -0.32)
            pose.rightHand = SIMD3<Float>(-0.86, 0.13, 0.32)
            pose.leftElbow = aimLimb(
                from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(-0.4, 0, -1)
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(-0.4, 0, 1)
            )
            pose.leftAnkle = SIMD3<Float>(1.18, 0.14, -0.16)
            pose.rightAnkle = SIMD3<Float>(1.18, 0.14, 0.16)
            pose.leftKnee = aimLimb(
                from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(0, -1, 0), offset: 0.2
            )
            pose.rightKnee = aimLimb(
                from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(0, -1, 0), offset: 0.2
            )
            return PoseSketch(pose)

        case .squat:
            return PoseSketch(squatPose(drop: effort * 0.44))

        case .squatHold:
            // Held at the bottom, breathing. The only thing that moves is the
            // ribcage — which is the difference between a hold that reads as a
            // hold and one that reads as a frozen frame.
            return PoseSketch(squatPose(drop: 0.42 + breath * 0.012))

        case .lunge:
            var pose = standing()
            // Alternating, and the swap is invisible because both feet come back
            // under the hips at the top of every cycle: at swing zero this is
            // simply standing, whichever leg is about to move.
            let reach = abs(swing)
            let drop = reach * 0.40
            let stepsBackWithLeft = swing >= 0
            let front = SIMD3<Float>(0.30 * reach, 0.11, 0)
            let back = SIMD3<Float>(-0.40 * reach, 0.11 + drop * 0.20, 0)
            if stepsBackWithLeft {
                pose.leftAnkle = SIMD3<Float>(back.x, back.y, -0.17)
                pose.rightAnkle = SIMD3<Float>(front.x, front.y, 0.17)
            } else {
                pose.rightAnkle = SIMD3<Float>(back.x, back.y, 0.17)
                pose.leftAnkle = SIMD3<Float>(front.x, front.y, -0.17)
            }
            moveHips(&pose, by: SIMD3<Float>(-0.03 * reach, -drop, 0))
            plantKneesForward(&pose)
            curlTorso(&pose, amount: reach * 0.10)
            return PoseSketch(pose)

        case .lateralLunge:
            var pose = standing()
            let reach = abs(swing)
            let step = 0.55 * reach
            let sink = 0.28 * reach
            let toLeft = swing >= 0
            if toLeft {
                pose.leftAnkle = SIMD3<Float>(0.02 * reach, 0.11, -0.16 - step)
                pose.rightAnkle = SIMD3<Float>(0, 0.11, 0.16)
            } else {
                pose.rightAnkle = SIMD3<Float>(0.02 * reach, 0.11, 0.16 + step)
                pose.leftAnkle = SIMD3<Float>(0, 0.11, -0.16)
            }
            // The seat travels toward the leg that bends, which is what makes
            // this a lunge rather than a wide squat.
            moveHips(&pose, by: SIMD3<Float>(-0.05 * reach, -sink, (toLeft ? -1 : 1) * step * 0.5))
            plantKneesForward(&pose)
            curlTorso(&pose, amount: reach * 0.24)
            return PoseSketch(pose)

        case .wallSit:
            var pose = standing()
            // Back vertical against the wall, thighs horizontal, shins vertical.
            // Leaving the chest where standing put it made the spine solve into
            // a long slab tipped backwards.
            let settle = breath * 0.02
            pose.pelvis = SIMD3<Float>(-0.2, 0.6 + settle, 0)
            pose.chest = SIMD3<Float>(-0.22, 1.18 + settle, 0)
            pose.neck = SIMD3<Float>(-0.22, 1.44 + settle, 0)
            pose.head = SIMD3<Float>(-0.2, 1.57 + settle, 0)
            pose.leftShoulder = SIMD3<Float>(-0.22, 1.18 + settle, -0.25)
            pose.rightShoulder = SIMD3<Float>(-0.22, 1.18 + settle, 0.25)
            pose.leftHip = SIMD3<Float>(-0.2, 0.6 + settle, -0.155)
            pose.rightHip = SIMD3<Float>(-0.2, 0.6 + settle, 0.155)
            pose.leftKnee = SIMD3<Float>(0.3, 0.61 + settle, -0.17)
            pose.rightKnee = SIMD3<Float>(0.3, 0.61 + settle, 0.17)
            pose.leftAnkle = SIMD3<Float>(0.32, 0.11, -0.17)
            pose.rightAnkle = SIMD3<Float>(0.32, 0.11, 0.17)
            // Arms reach forward, which is both what people do and what keeps
            // them off the trunk in profile.
            pose.leftHand = SIMD3<Float>(0.46, 1.1 + settle, -0.26)
            pose.rightHand = SIMD3<Float>(0.46, 1.1 + settle, 0.26)
            pose.leftElbow = aimLimb(from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(0, -1, -0.3))
            pose.rightElbow = aimLimb(from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(0, -1, 0.3))
            return PoseSketch(pose)

        case .calfRaise:
            var pose = standing()
            // Heels rise; the toes stay down, and the foot clamp keeps them there.
            let rise = effort * 0.13
            pose.leftAnkle.y += rise
            pose.rightAnkle.y += rise
            moveHips(&pose, by: SIMD3<Float>(0, rise, 0))
            return PoseSketch(pose)

        case .goodMorning:
            var pose = standing()
            // Hands behind the head, then the trunk folds over the hips while
            // the shins stay vertical. The hips travelling back is what keeps
            // this a hinge instead of a bow.
            // Arms crossed on the chest rather than behind the head: behind the
            // head they sit inside the body's own outline, and in profile the
            // athlete simply had no arms.
            armsCrossedOnChest(&pose)
            moveHips(&pose, by: SIMD3<Float>(-0.18 * effort, -0.06 * effort, 0))
            curlTorso(&pose, amount: effort * 1.12)
            plantKneesForward(&pose, offset: 0.12)
            return PoseSketch(pose)

        case .donkeyKick:
            var pose = quadruped()
            // One heel drives up and back while the pelvis stays exactly where
            // it was; the moment the hips rotate, the glute stops working.
            let lift = abs(swing)
            let target = SIMD3<Float>(0.92, 0.60, 0)
            if swing >= 0 {
                pose.leftAnkle = mix(pose.leftAnkle, target + SIMD3<Float>(0, 0, 0.17), t: lift)
                pose.leftKnee = aimLimb(
                    from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(0, -1, 0), offset: 0.16
                )
            } else {
                pose.rightAnkle = mix(pose.rightAnkle, target + SIMD3<Float>(0, 0, -0.17), t: lift)
                pose.rightKnee = aimLimb(
                    from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(0, -1, 0), offset: 0.16
                )
            }
            return PoseSketch(pose, anchor: \.leftHand)

        case .pushUp:
            return PoseSketch(pushUpPose(dip: effort * 0.30))

        case .kneePushUp:
            return PoseSketch(kneePushUpPose(dip: effort * 0.26))

        case .wallPushUp:
            var pose = standing()
            // The hands are planted where the wall is and the body tips toward
            // them in one piece, so the arms take the whole movement.
            pose.leftHand = SIMD3<Float>(0.66, 1.62, -0.32)
            pose.rightHand = SIMD3<Float>(0.66, 1.62, 0.32)
            pose = pivoted(
                pose,
                about: (pose.leftAnkle + pose.rightAnkle) * 0.5,
                by: 0.03 + effort * 0.17,
                holding: [\.leftHand, \.rightHand, \.leftAnkle, \.rightAnkle]
            )
            pose.leftElbow = aimLimb(
                from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(0, -1, -0.5)
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(0, -1, 0.5)
            )
            return PoseSketch(pose)

        case .pikePushUp:
            var pose = highPlank()
            // Hands and feet walk toward each other, then the hips ride up into
            // an inverted V and the torso pitches down between the hands. Pitch
            // is a rotation about the pelvis rather than a new chest position,
            // so the spine keeps its length instead of stretching into a slab.
            pose.leftHand = SIMD3<Float>(-0.58, 0.13, 0.3)
            pose.rightHand = SIMD3<Float>(-0.58, 0.13, -0.3)
            pose.leftAnkle = SIMD3<Float>(0.94, 0.13, 0.2)
            pose.rightAnkle = SIMD3<Float>(0.94, 0.13, -0.2)
            // Hip height is bounded by the legs: raised any further and the
            // pelvis sits more than a leg's length from the planted feet, which
            // leaves the solver to invent the difference.
            moveHips(&pose, by: SIMD3<Float>(0.31, 0.29, 0))

            let pikeAxis = safeAxis(pose.leftHip - pose.rightHip, fallback: SIMD3<Float>(0, 0, 1))
            let pitch = 1.02 + effort * 0.2
            for joint in upperBodyJoints where joint != \.leftHand && joint != \.rightHand {
                pose[keyPath: joint] = rotate(
                    pose[keyPath: joint], around: pose.pelvis, axis: pikeAxis, angle: pitch
                )
            }
            pose.leftKnee = aimLimb(from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(0, -1, 0))
            pose.rightKnee = aimLimb(from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(0, -1, 0))
            pose.leftElbow = aimLimb(from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(0, 0, 1))
            pose.rightElbow = aimLimb(from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(0, 0, -1))
            return PoseSketch(pose)

        case .floorDip:
            var pose = seated()
            // Hands planted just behind the shoulders, feet flat, seat off the
            // mat. The hands are under the shoulders rather than further back
            // because the arm is 0.70 long: any further and the shoulder could
            // never reach the height a locked-out dip needs.
            let seat = mix(0.32, 0.20, t: effort)
            pose.leftAnkle = SIMD3<Float>(0.86, 0.13, -0.17)
            pose.rightAnkle = SIMD3<Float>(0.86, 0.13, 0.17)
            pose.leftHand = SIMD3<Float>(-0.20, 0.13, -0.32)
            pose.rightHand = SIMD3<Float>(-0.20, 0.13, 0.32)
            pose.pelvis = SIMD3<Float>(mix(0.18, 0.14, t: effort), seat, 0)
            pose.leftHip = pose.pelvis + SIMD3<Float>(0, 0, -0.155)
            pose.rightHip = pose.pelvis + SIMD3<Float>(0, 0, 0.155)
            pose.chest = SIMD3<Float>(mix(-0.14, -0.18, t: effort), seat + 0.48, 0)
            pose.leftShoulder = pose.chest + SIMD3<Float>(0, 0, -0.25)
            pose.rightShoulder = pose.chest + SIMD3<Float>(0, 0, 0.25)
            pose.neck = pose.chest + SIMD3<Float>(-0.02, 0.26, 0)
            pose.head = pose.neck + SIMD3<Float>(0.02, 0.13, 0)
            pose.leftKnee = aimLimb(
                from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(0, 1, 0), offset: 0.2
            )
            pose.rightKnee = aimLimb(
                from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(0, 1, 0), offset: 0.2
            )
            pose.leftElbow = aimLimb(
                from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(-1, 0, -0.2)
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(-1, 0, 0.2)
            )
            return PoseSketch(pose)

        case .proneRow:
            var pose = prone()
            let pull = effort
            // The chest lifts a little and the elbows drive back past the ribs.
            // A row is a folded arm, not a reach: the hand finishes near the
            // shoulder, which is why the targets sit so close in.
            let lift = pull * 0.11
            pose.chest.y += lift
            pose.leftShoulder.y += lift
            pose.rightShoulder.y += lift
            pose.neck.y += lift * 1.2
            pose.head.y += lift * 1.4
            pose.leftHand = mix(pose.leftHand, SIMD3<Float>(-0.62, 0.26, 0.50), t: pull)
            pose.rightHand = mix(pose.rightHand, SIMD3<Float>(-0.62, 0.26, -0.50), t: pull)
            pose.leftElbow = aimLimb(
                from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(-0.3, 1, 0.7)
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(-0.3, 1, -0.7)
            )
            return PoseSketch(pose, anchor: \.pelvis)

        case .plankUpDown:
            var pose = forearmPlank()
            let extend = abs(swing)
            let high = highPlank()
            // The girdle rolls rather than the whole trunk rising: an elbow on
            // the mat sits 0.38 below its own shoulder and not a millimetre
            // more, so a trunk lifted to high-plank height would have to tear
            // the planted forearm off the ground.
            let axis = safeAxis(pose.chest - pose.pelvis, fallback: SIMD3<Float>(-1, 0, 0))
            for joint in shoulderGirdleJoints {
                pose[keyPath: joint] = rotate(
                    pose[keyPath: joint],
                    around: pose.chest,
                    axis: axis,
                    angle: extend * 0.3 * (swing >= 0 ? 1 : -1)
                )
            }
            if swing >= 0 {
                pose.leftHand = mix(pose.leftHand, high.leftHand, t: extend)
            } else {
                pose.rightHand = mix(pose.rightHand, high.rightHand, t: extend)
            }
            // Both arms, every frame: the arm that stays down is the one whose
            // shoulder is being rolled over it, and leaving its elbow where the
            // stance put it is what let the solver flip it mid-roll.
            stabiliseLimbs(&pose)
            moveHips(&pose, by: SIMD3<Float>(0, extend * 0.015, 0), carryingTorso: false)
            return PoseSketch(pose)

        case .squatThrust:
            // Four shapes rather than one deformed shape. A repetition genuinely
            // visits standing, a crouch and a plank, and authoring that as
            // offsets from a single stance is how a figure ends up melting.
            return PoseSketch(
                sequence(
                    [uprightForMat(), crouch(), highPlank(), crouch()],
                    phase: phase
                )
            )

        case .burpee:
            return PoseSketch(
                sequence(
                    [
                        uprightForMat(),
                        crouch(),
                        highPlank(),
                        pushUpPose(dip: 0.30),
                        highPlank(),
                        crouch(),
                        reachOverhead()
                    ],
                    phase: phase
                )
            )

        case .jumpingJack:
            var pose = standing()
            let open = (swing + 1) / 2
            let spread = 0.30 * open
            pose.leftAnkle = SIMD3<Float>(0, 0.11, -0.16 - spread)
            pose.rightAnkle = SIMD3<Float>(0, 0.11, 0.16 + spread)
            moveHips(&pose, by: SIMD3<Float>(0, -0.05 * open, 0))
            pose.leftKnee = aimLimb(
                from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(1, 0, 0), offset: 0.12
            )
            pose.rightKnee = aimLimb(
                from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(1, 0, 0), offset: 0.12
            )
            // The arms sweep in the frontal plane, so the hand rides a circle
            // around its own shoulder rather than being placed by hand at each
            // end and interpolated through the torso.
            let angle = mix(-1.25, 0.95, t: open)
            let radius: Float = 0.62
            pose.leftHand = pose.leftShoulder
                + SIMD3<Float>(0.04, sin(angle) * radius, -cos(angle) * radius)
            pose.rightHand = pose.rightShoulder
                + SIMD3<Float>(0.04, sin(angle) * radius, cos(angle) * radius)
            pose.leftElbow = aimLimb(
                from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(1, 0, 0), offset: 0.1
            )
            pose.rightElbow = aimLimb(
                from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(1, 0, 0), offset: 0.1
            )
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
        // Arms reach for the ceiling but splay apart, otherwise the two land on
        // top of each other in profile and read as one stick. Kept inside the
        // arm's reach: pushed to full extension the elbow has nowhere to bend
        // and its hint goes unstable.
        pose.leftHand = SIMD3<Float>(-0.46, 0.86, -0.36)
        pose.rightHand = SIMD3<Float>(-0.46, 0.86, 0.36)
        pose.leftElbow = aimLimb(
            from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(0.4, 0, -1)
        )
        pose.rightElbow = aimLimb(
            from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(0.4, 0, 1)
        )
        return pose
    }

    /// Hands under the shoulders, arms straight but not locked.
    ///
    /// The shoulders used to sit 0.73 above the hands while an arm measures
    /// 0.70, so the target was out of reach and the solver answered the only
    /// way it can: full extension, every frame. That is why every plank in the
    /// app drew its arms as two identical pencil lines with no elbow — the pose
    /// left no room for one. Lowered to 0.66, the arm keeps a little slack and
    /// the elbow shows.
    static func highPlank() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-0.98, 0.8, 0),
            neck: SIMD3<Float>(-0.78, 0.82, 0),
            chest: SIMD3<Float>(-0.48, 0.79, 0),
            pelvis: SIMD3<Float>(0.04, 0.66, 0),
            leftShoulder: SIMD3<Float>(-0.48, 0.79, 0.27),
            rightShoulder: SIMD3<Float>(-0.48, 0.79, -0.27),
            leftElbow: SIMD3<Float>(-0.46, 0.46, 0.33),
            rightElbow: SIMD3<Float>(-0.46, 0.46, -0.33),
            leftHand: SIMD3<Float>(-0.48, 0.13, 0.27),
            rightHand: SIMD3<Float>(-0.48, 0.13, -0.27),
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

    /// Back level, not sloping.
    ///
    /// The chest sat 0.14 above the pelvis, which drew every all-fours movement
    /// as someone bent over their own hands — and put the shoulders 0.73 above
    /// the floor when an arm only reaches 0.70, so the arms came out straight
    /// sticks for the same reason the plank's did. A table top fixes both.
    static func quadruped() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-0.95, 0.78, 0),
            neck: SIMD3<Float>(-0.76, 0.79, 0),
            chest: SIMD3<Float>(-0.45, 0.76, 0),
            pelvis: SIMD3<Float>(0.13, 0.75, 0),
            leftShoulder: SIMD3<Float>(-0.45, 0.76, 0.27),
            rightShoulder: SIMD3<Float>(-0.45, 0.76, -0.27),
            leftElbow: SIMD3<Float>(-0.44, 0.45, 0.32),
            rightElbow: SIMD3<Float>(-0.44, 0.45, -0.32),
            leftHand: SIMD3<Float>(-0.45, 0.13, 0.25),
            rightHand: SIMD3<Float>(-0.45, 0.13, -0.25),
            leftHip: SIMD3<Float>(0.13, 0.75, 0.16),
            rightHip: SIMD3<Float>(0.13, 0.75, -0.16),
            leftKnee: SIMD3<Float>(0.16, 0.23, 0.17),
            rightKnee: SIMD3<Float>(0.16, 0.23, -0.17),
            leftAnkle: SIMD3<Float>(0.64, 0.14, 0.17),
            rightAnkle: SIMD3<Float>(0.64, 0.14, -0.17)
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
            leftElbow: SIMD3<Float>(0.12, 1.33, -0.29),
            rightElbow: SIMD3<Float>(0.12, 1.33, 0.29),
            leftHand: SIMD3<Float>(0.22, 1.04, -0.31),
            rightHand: SIMD3<Float>(0.22, 1.04, 0.31),
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

    /// Flat on one side, the way a side crunch starts. The side plank is
    /// propped up on an elbow, which is a different shape entirely.
    static func sideLying() -> BodyPose {
        BodyPose(
            head: SIMD3<Float>(-1.0, 0.33, 0.02),
            neck: SIMD3<Float>(-0.79, 0.31, 0.01),
            chest: SIMD3<Float>(-0.47, 0.3, 0),
            pelvis: SIMD3<Float>(0.11, 0.25, 0),
            leftShoulder: SIMD3<Float>(-0.47, 0.13, 0.16),
            rightShoulder: SIMD3<Float>(-0.47, 0.55, -0.16),
            leftElbow: SIMD3<Float>(-0.8, 0.14, 0.14),
            rightElbow: SIMD3<Float>(-0.62, 0.72, -0.2),
            leftHand: SIMD3<Float>(-1.12, 0.14, 0.12),
            rightHand: SIMD3<Float>(-0.88, 0.52, -0.16),
            leftHip: SIMD3<Float>(0.11, 0.14, 0.09),
            rightHip: SIMD3<Float>(0.11, 0.36, -0.09),
            leftKnee: SIMD3<Float>(0.63, 0.13, 0.09),
            rightKnee: SIMD3<Float>(0.63, 0.33, -0.09),
            leftAnkle: SIMD3<Float>(1.13, 0.13, 0.09),
            rightAnkle: SIMD3<Float>(1.13, 0.32, -0.09)
        )
    }

    /// A squat at a given depth.
    ///
    /// The hips travel back as well as down: a squat that only sinks reads as a
    /// knee bend and puts the load in the wrong place.
    static func squatPose(drop: Float) -> BodyPose {
        var pose = standing()
        moveHips(&pose, by: SIMD3<Float>(-drop * 0.42, -drop, 0))
        plantKneesForward(&pose)
        curlTorso(&pose, amount: drop * 1.14)
        return pose
    }

    /// Standing, turned to face the way the mat stances lie.
    ///
    /// `standing()` faces +X and every stance on the mat puts its head at −X.
    /// Blended directly, the athlete bends over *backwards* to place their hands
    /// — and the feet pass through a vertical shin on the way, which is the one
    /// configuration the foot direction cannot be read from. Turning the stance
    /// around first makes the burpee a fold forwards, which is both what it is
    /// and what removed the flip.
    static func uprightForMat() -> BodyPose {
        turnedAround(standing())
    }

    /// Hands on the mat, heels down, knees deeply folded — the shape a burpee
    /// passes through twice per repetition.
    static func crouch() -> BodyPose {
        var pose = BodyPose(
            head: SIMD3<Float>(-0.34, 0.94, 0),
            neck: SIMD3<Float>(-0.26, 0.86, 0),
            chest: SIMD3<Float>(-0.10, 0.66, 0),
            pelvis: SIMD3<Float>(0.46, 0.52, 0),
            leftShoulder: SIMD3<Float>(-0.10, 0.66, 0.25),
            rightShoulder: SIMD3<Float>(-0.10, 0.66, -0.25),
            leftElbow: SIMD3<Float>(-0.28, 0.40, 0.30),
            rightElbow: SIMD3<Float>(-0.28, 0.40, -0.30),
            leftHand: SIMD3<Float>(-0.42, 0.13, 0.28),
            rightHand: SIMD3<Float>(-0.42, 0.13, -0.28),
            leftHip: SIMD3<Float>(0.46, 0.52, 0.155),
            rightHip: SIMD3<Float>(0.46, 0.52, -0.155),
            leftKnee: SIMD3<Float>(0.62, 0.44, 0.17),
            rightKnee: SIMD3<Float>(0.62, 0.44, -0.17),
            leftAnkle: SIMD3<Float>(0.80, 0.11, 0.17),
            rightAnkle: SIMD3<Float>(0.80, 0.11, -0.17)
        )
        // Knees in front of the ankles, which is where they are in a deep crouch
        // — and which is what points the toes forwards rather than back under
        // the athlete. `plantKneesForward` bows them the other way: it is written
        // for a stance facing +X, and this one has been turned around.
        pose.leftKnee = aimLimb(
            from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(-1, 0, 0), offset: 0.2
        )
        pose.rightKnee = aimLimb(
            from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(-1, 0, 0), offset: 0.2
        )
        return pose
    }

    /// The end of a burpee: standing tall with the arms swung up and forward.
    ///
    /// Not straight overhead. The shoulder sits 1.70 up and an arm is 0.70, so
    /// a vertical reach puts the hands at 2.40 — past the top of the frame.
    static func reachOverhead() -> BodyPose {
        var pose = uprightForMat()
        pose.leftHand = SIMD3<Float>(-0.42, 2.06, 0.36)
        pose.rightHand = SIMD3<Float>(-0.42, 2.06, -0.36)
        pose.leftElbow = aimLimb(
            from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(-0.4, -1, 0)
        )
        pose.rightElbow = aimLimb(
            from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(-0.4, -1, 0)
        )
        return PoseSolver.translate(pose, by: SIMD3<Float>(0, 0.05, 0))
    }

    /// A push-up at a given depth.
    ///
    /// The body turns as one about the toes; the hands are planted, so the arms
    /// bend to take it. Lowering the hips instead folds the athlete in half.
    static func pushUpPose(dip: Float) -> BodyPose {
        var pose = highPlank()
        // Hands a little ahead of and wider than the shoulders, so the two arms
        // separate in profile and the bend actually shows.
        pose.leftHand = SIMD3<Float>(-0.62, 0.13, 0.32)
        pose.rightHand = SIMD3<Float>(-0.62, 0.13, -0.32)
        pose = pivoted(pose, about: (pose.leftAnkle + pose.rightAnkle) * 0.5, by: dip)
        // Re-aimed after the rotation, not before: the hands are planted, so it
        // is the descent itself that has to bend the arms.
        pose.leftElbow = aimLimb(
            from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(0, 0, 1)
        )
        pose.rightElbow = aimLimb(
            from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(0, 0, -1)
        )
        return pose
    }

    /// The same movement pivoted about the knees instead of the toes, which is
    /// the whole difference between the two exercises.
    static func kneePushUpPose(dip: Float) -> BodyPose {
        var pose = BodyPose(
            head: SIMD3<Float>(-0.70, 0.83, 0),
            neck: SIMD3<Float>(-0.58, 0.80, 0),
            chest: SIMD3<Float>(-0.33, 0.74, 0),
            pelvis: SIMD3<Float>(0.22, 0.55, 0),
            leftShoulder: SIMD3<Float>(-0.33, 0.74, 0.25),
            rightShoulder: SIMD3<Float>(-0.33, 0.74, -0.25),
            leftElbow: SIMD3<Float>(-0.34, 0.42, 0.31),
            rightElbow: SIMD3<Float>(-0.34, 0.42, -0.31),
            leftHand: SIMD3<Float>(-0.36, 0.13, 0.30),
            rightHand: SIMD3<Float>(-0.36, 0.13, -0.30),
            leftHip: SIMD3<Float>(0.22, 0.55, 0.155),
            rightHip: SIMD3<Float>(0.22, 0.55, -0.155),
            leftKnee: SIMD3<Float>(0.50, 0.13, 0.16),
            rightKnee: SIMD3<Float>(0.50, 0.13, -0.16),
            leftAnkle: SIMD3<Float>(0.90, 0.45, 0.16),
            rightAnkle: SIMD3<Float>(0.90, 0.45, -0.16)
        )
        pose = pivoted(
            pose,
            about: (pose.leftKnee + pose.rightKnee) * 0.5,
            by: dip,
            holding: [\.leftHand, \.rightHand, \.leftKnee, \.rightKnee, \.leftAnkle, \.rightAnkle]
        )
        pose.leftElbow = aimLimb(
            from: pose.leftShoulder, to: pose.leftHand, bend: SIMD3<Float>(0, 0, 1)
        )
        pose.rightElbow = aimLimb(
            from: pose.rightShoulder, to: pose.rightHand, bend: SIMD3<Float>(0, 0, -1)
        )
        return pose
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
            // Stacked, one hip above the other — but at the real pelvic span,
            // which the shorter offsets were not.
            leftHip: SIMD3<Float>(0.11, 0.349, 0.082),
            rightHip: SIMD3<Float>(0.11, 0.611, -0.082),
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
    /// Moves the hips through space and carries the rest of the body with them.
    ///
    /// A base stance authors the whole skeleton at once, so displacing the
    /// pelvis on its own leaves the chest and hips behind: the spine stretches
    /// into a slab, the hips tear away from the pelvis, and any later rotation
    /// about the pelvis swings the torso through a radius it should never have
    /// had. Standing movements travel — supine hip lifts genuinely do pivot the
    /// pelvis alone, and those still set it directly.
    /// - Parameter carryingTorso: false for hip lifts, where the shoulders stay
    ///   planted and only the pelvis end of the spine travels. The hip joints
    ///   always follow — they are bolted to the pelvis, not to the mat.
    static func moveHips(_ pose: inout BodyPose, by delta: SIMD3<Float>, carryingTorso: Bool = true) {
        if carryingTorso {
            for joint in upperBodyJoints {
                pose[keyPath: joint] += delta
            }
        }
        pose.pelvis += delta
        pose.leftHip += delta
        pose.rightHip += delta
    }

    /// Re-aims both knees so the ankles stay where they are.
    ///
    /// Any movement that raises the hips over planted feet needs this: the
    /// thigh is a fixed bone, so if it is not rotated to follow the pelvis it
    /// simply stretches, and the solver buys the extra length back by pulling
    /// the foot off the mat.
    static func plantFeet(_ pose: inout BodyPose) {
        pose.leftKnee = aimLimb(
            from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(0, 1, 0), offset: 0.2
        )
        pose.rightKnee = aimLimb(
            from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(0, 1, 0), offset: 0.2
        )
    }

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

    /// Turns the whole athlete about the vertical through their hips.
    ///
    /// The projection is a single fixed viewpoint for every movement, which is
    /// what keeps the figure consistent — so a pose that reads badly from the
    /// side cannot ask for its own camera. It can turn instead, which comes to
    /// the same thing and costs nothing anywhere else.
    static func yaw(_ pose: inout BodyPose, by angle: Float) {
        let pivot = pose.pelvis
        let axis = SIMD3<Float>(0, 1, 0)
        for joint in allJoints {
            pose[keyPath: joint] = rotate(pose[keyPath: joint], around: pivot, axis: axis, angle: angle)
        }
    }

    /// Arms folded across the chest.
    ///
    /// Was hands behind the head, and no arrangement of the elbows could fix
    /// what that draws: two arms straddling the skull leave a pocket of
    /// background between them, and a small dark shape ringed by white reads as
    /// a hole punched in the athlete however real it is. Crossing the arms
    /// removes it — and it is the better cue anyway. Hands at the head is what
    /// makes people haul on their own neck, which is exactly why these
    /// movements were the ones excluded from neck-friendly sessions.
    static func armsCrossedOnChest(_ pose: inout BodyPose) {
        let lateral = safeAxis(pose.leftShoulder - pose.rightShoulder, fallback: SIMD3<Float>(0, 0, 1))
        let up = safeAxis(pose.chest - pose.pelvis, fallback: SIMD3<Float>(0, 1, 0))
        let front = safeAxis(pose.front, fallback: SIMD3<Float>(0, 0, 1))

        // Each hand rests on the opposite shoulder, so the forearms lie across
        // the chest and touch: one mass, nothing enclosed.
        pose.leftHand = pose.rightShoulder + lateral * 0.04 + front * 0.09 - up * 0.02
        pose.rightHand = pose.leftShoulder - lateral * 0.04 + front * 0.09 - up * 0.02
        pose.leftElbow = aimLimb(
            from: pose.leftShoulder, to: pose.leftHand, bend: front * 0.6 - up
        )
        pose.rightElbow = aimLimb(
            from: pose.rightShoulder, to: pose.rightHand, bend: front * 0.6 - up
        )
    }

    /// Hands slide under the seat, which is where they belong for flutter and
    /// scissors and keeps them clear of the sweeping legs.
    static func tuckHandsUnderSeat(_ pose: inout BodyPose) {
        let lateral = safeAxis(pose.leftHip - pose.rightHip, fallback: SIMD3<Float>(0, 0, 1))
        pose.leftHand = pose.pelvis + lateral * 0.1 - SIMD3<Float>(0.04, 0.07, 0)
        pose.rightHand = pose.pelvis - lateral * 0.1 - SIMD3<Float>(0.04, 0.07, 0)
        pose.leftElbow = aimLimb(from: pose.leftShoulder, to: pose.leftHand, bend: lateral)
        pose.rightElbow = aimLimb(from: pose.rightShoulder, to: pose.rightHand, bend: -lateral)
    }

    static func armsOverhead(_ pose: inout BodyPose) {
        let back = safeAxis(pose.head - pose.chest, fallback: SIMD3<Float>(-1, 0, 0))
        pose.leftHand = pose.leftShoulder + back * 0.66 + SIMD3<Float>(0, 0.34, -0.06)
        pose.rightHand = pose.rightShoulder + back * 0.66 + SIMD3<Float>(0, 0.34, 0.06)
        pose.leftElbow = pose.leftShoulder + back * 0.35 + SIMD3<Float>(0, 0.19, -0.02)
        pose.rightElbow = pose.rightShoulder + back * 0.35 + SIMD3<Float>(0, 0.19, 0.02)
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
    /// A bend hint perpendicular to the limb by construction, in the plane the
    /// body faces. A fixed hint is fine for a limb that barely moves; across a
    /// sweep from horizontal to vertical it passes through parallel, and a hint
    /// parallel to the limb is the ill-conditioned case that snaps the joint
    /// from one side to the other between two frames.
    static func sagittalBend(from root: SIMD3<Float>, to target: SIMD3<Float>, sign: Float = 1) -> SIMD3<Float> {
        let axis = safeAxis(target - root, fallback: SIMD3<Float>(1, 0, 0))
        return simd_cross(axis, SIMD3<Float>(0, 0, 1)) * sign
    }

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
        // Face down, bending a knee lifts the heel and puts the knee below the
        // hip-to-ankle line. Aimed above it, the leg folded backwards.
        let lift = SIMD3<Float>(0, -1, 0)

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
            let hand = SIMD3<Float>(-1.2, 1.0, 0.21)
            let ankle = SIMD3<Float>(1.24, 0.82, -0.16)
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
            let hand = SIMD3<Float>(-1.2, 1.0, -0.21)
            let ankle = SIMD3<Float>(1.24, 0.82, 0.16)
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

    static let allJoints: [any WritableKeyPath<BodyPose, SIMD3<Float>> & Sendable] = [
        \.head, \.neck, \.chest, \.pelvis,
        \.leftShoulder, \.rightShoulder, \.leftElbow, \.rightElbow, \.leftHand, \.rightHand,
        \.leftHip, \.rightHip, \.leftKnee, \.rightKnee, \.leftAnkle, \.rightAnkle
    ]

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

    /// Re-aims both knees so they lead forward over the planted feet.
    ///
    /// Any standing movement that sinks needs this: the thigh is a fixed bone,
    /// so a pelvis that drops without the knees being re-aimed simply stretches
    /// it, and the solver buys the length back by dragging a foot off the mat.
    static func plantKneesForward(_ pose: inout BodyPose, offset: Float = 0.2) {
        pose.leftKnee = aimLimb(
            from: pose.leftHip, to: pose.leftAnkle, bend: SIMD3<Float>(1, 0, 0), offset: offset
        )
        pose.rightKnee = aimLimb(
            from: pose.rightHip, to: pose.rightAnkle, bend: SIMD3<Float>(1, 0, 0), offset: offset
        )
    }

    /// Turns the whole body about one point, leaving the listed joints planted.
    ///
    /// A push-up, a knee push-up and a wall push-up are the same movement about
    /// three different pivots, and writing that once means the sign of the
    /// rotation is decided in one place rather than three.
    static func pivoted(
        _ pose: BodyPose,
        about pivot: SIMD3<Float>,
        by angle: Float,
        holding planted: [any WritableKeyPath<BodyPose, SIMD3<Float>> & Sendable] = [\.leftHand, \.rightHand]
    ) -> BodyPose {
        var result = pose
        let axis = safeAxis(pose.leftHip - pose.rightHip, fallback: SIMD3<Float>(0, 0, 1))
        for joint in allJoints where !planted.contains(where: { $0 == joint }) {
            result[keyPath: joint] = rotate(pose[keyPath: joint], around: pivot, axis: axis, angle: angle)
        }
        return result
    }

    /// Turns the athlete to face the other way.
    ///
    /// Half a turn about the vertical, not a mirror. A mirrored body is a
    /// left-handed body: the two sides swap over, and the difference shows the
    /// moment an arm crosses the chest or a foot is asked which way its toes
    /// point.
    static func turnedAround(_ pose: BodyPose) -> BodyPose {
        var result = pose
        for joint in allJoints {
            let point = pose[keyPath: joint]
            result[keyPath: joint] = SIMD3<Float>(-point.x, point.y, -point.z)
        }
        return result
    }

    static func blend(_ from: BodyPose, _ to: BodyPose, t: Float) -> BodyPose {
        var result = from
        for joint in allJoints {
            result[keyPath: joint] = mix(from[keyPath: joint], to[keyPath: joint], t: t)
        }
        return result
    }

    /// A movement authored as key poses rather than as one stance being
    /// deformed.
    ///
    /// Some repetitions are not a single shape: a burpee visits standing, the
    /// mat, a plank and a jump inside one of them. Keyframing those and letting
    /// the solver rebuild the bones in between is how animation has always
    /// handled it.
    ///
    /// Two details do the work. The keys are spaced by **how far the body
    /// actually travels** between them rather than by hand-written phases: a
    /// hand-written schedule gives every segment the same slice of the cycle
    /// whatever it contains, so the long move from standing to the mat runs
    /// three times faster than the short one out of the plank, and the fast one
    /// reads as a jump. And the limbs are re-aimed after every blend, because
    /// interpolating an elbow between two stances walks it through the position
    /// where it is in line with its own arm — the one case two-bone IK cannot
    /// resolve, which it answers by flipping the joint to the other side between
    /// one frame and the next.
    ///
    /// The list wraps: the last pose leads back into the first, so the loop
    /// closes by construction.
    static func sequence(_ poses: [BodyPose], phase: Float) -> BodyPose {
        guard let first = poses.first else { return standing() }
        guard poses.count > 1 else { return first }

        let loop = poses + [first]
        var spans: [Float] = []
        for index in 0..<(loop.count - 1) {
            spans.append(travel(from: loop[index], to: loop[index + 1]))
        }
        let total = spans.reduce(0, +)
        guard total > 0.0001 else { return first }
        // A floor per segment, so two nearly identical keys still take a moment
        // rather than being stepped through inside a single frame.
        let floor = total * 0.04
        spans = spans.map { max($0, floor) }
        let scale = spans.reduce(0, +)

        var cursor: Float = 0
        let phase = MotionTempo.wrap(phase) * scale
        for index in spans.indices {
            let span = spans[index]
            if phase < cursor + span || index == spans.count - 1 {
                let progress = span > 0.0001 ? (phase - cursor) / span : 0
                var pose = blend(loop[index], loop[index + 1], t: MotionTempo.smoothstep(min(max(progress, 0), 1)))
                stabiliseLimbs(&pose)
                return pose
            }
            cursor += span
        }
        return first
    }

    /// The furthest any single joint moves between two poses — the honest
    /// measure of how much animation a segment contains.
    private static func travel(from: BodyPose, to: BodyPose) -> Float {
        allJoints.reduce(0) { longest, joint in
            max(longest, simd_distance(from[keyPath: joint], to[keyPath: joint]))
        }
    }

    /// Re-aims the four limbs away from their own axis.
    ///
    /// The bend hint only has to be *somewhere off the line* for the solver to
    /// resolve a limb the same way two frames running. `sagittalBend` puts it in
    /// the plane the body moves in, which is where a real elbow and a real knee
    /// both bend.
    static func stabiliseLimbs(_ pose: inout BodyPose) {
        pose.leftElbow = aimLimb(
            from: pose.leftShoulder,
            to: pose.leftHand,
            bend: sagittalBend(from: pose.leftShoulder, to: pose.leftHand),
            offset: 0.1
        )
        pose.rightElbow = aimLimb(
            from: pose.rightShoulder,
            to: pose.rightHand,
            bend: sagittalBend(from: pose.rightShoulder, to: pose.rightHand),
            offset: 0.1
        )
        pose.leftKnee = aimLimb(
            from: pose.leftHip,
            to: pose.leftAnkle,
            bend: sagittalBend(from: pose.leftHip, to: pose.leftAnkle, sign: -1),
            offset: 0.16
        )
        pose.rightKnee = aimLimb(
            from: pose.rightHip,
            to: pose.rightAnkle,
            bend: sagittalBend(from: pose.rightHip, to: pose.rightAnkle, sign: -1),
            offset: 0.16
        )
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

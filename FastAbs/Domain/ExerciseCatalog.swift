import Foundation

/// Every movement the app can programme.
///
/// Grouped by `CorePattern` rather than by muscle: what the trunk is being
/// asked to do is the axis a session is balanced on, and reading the catalog in
/// that order makes the gaps visible. `minimumDifficulty` is a floor, not a
/// label — it says who can perform the movement with control, not who it is
/// aimed at, so several genuinely accessible movements sit at `.beginner` even
/// though they stay useful much later.
enum ExerciseCatalog {
    /// Built once. Looking an exercise up used to rebuild this map per record,
    /// which turned reading a history into quadratic work.
    static let byID: [String: Exercise] = Dictionary(
        uniqueKeysWithValues: all.map { ($0.id, $0) }
    )

    static let all: [Exercise] = antiExtension + antiRotation + antiLateralFlexion
        + dynamicFlexion + hipExtension

    // MARK: - Anti-extension
    //
    // Keeping the lower back from arching while something pulls it that way.
    // The largest group, and the one that carries most of the beginner pool.

    private static let antiExtension: [Exercise] = [
        ex("forearm-plank", "Planche avant", [.deepCore, .fullCore],
           family: .antiExtension, pattern: .antiExtension, level: .beginner, motion: .plank,
           setup: "Sur les avant-bras, coudes à l’aplomb des épaules, pieds écartés largeur de bassin.",
           instruction: "Pousse le sol avec les avant-bras, serre fessiers et cuisses, et tiens une ligne longue des talons au crâne.",
           breathing: "Respire bas dans le ventre, sans jamais bloquer.",
           mistake: "Laisser le bassin s’affaisser vers le sol ou monter en pointe.",
           tips: ["Serre les fessiers : c’est ce qui empêche le dos de se creuser.",
                  "Éloigne les épaules des oreilles.",
                  "Regarde le sol trente centimètres devant tes mains.",
                  "Si le bas du dos tire, arrête : la position est déjà perdue."],
           neck: true, intensity: 1.0),

        ex("shoulder-hold", "Planche haute", [.deepCore, .fullCore],
           family: .antiExtension, pattern: .antiExtension, level: .beginner, motion: .plank,
           setup: "Mains à l’aplomb des épaules, bras tendus, corps en ligne des talons au crâne.",
           instruction: "Repousse activement le sol pour arrondir très légèrement le haut du dos, et verrouille le bassin.",
           breathing: "Expire lentement sans perdre l’alignement.",
           mistake: "Verrouiller les coudes en hyperextension au lieu de garder les bras actifs.",
           tips: ["Pousse le sol comme si tu voulais t’en éloigner.",
                  "Garde les mains bien à plat, doigts écartés.",
                  "Le bassin ne bouge pas d’un centimètre."],
           neck: true, intensity: 1.05),

        ex("dead-bug", "Dead bug", [.deepCore, .lowerAbs],
           family: .antiExtension, pattern: .antiExtension, level: .beginner, motion: .deadBug,
           setup: "Sur le dos, bras tendus vers le plafond, jambes en tablette, lombaires plaquées.",
           instruction: "Allonge le bras et la jambe opposés au ras du sol pendant que le tronc reste absolument immobile.",
           breathing: "Expire pendant l’allongement, inspire au retour.",
           mistake: "Allonger trop vite et laisser le bas du dos décoller du sol.",
           tips: ["Le sol doit rester en contact avec tes lombaires du début à la fin.",
                  "Va aussi loin que le contact tient, pas plus.",
                  "Lent vaut mieux que long : c’est un exercice de contrôle."],
           side: .alternating, neck: true, intensity: 0.85),

        ex("toe-taps", "Talons alternés", [.lowerAbs, .deepCore],
           family: .antiExtension, pattern: .antiExtension, level: .beginner, motion: .deadBug,
           setup: "Sur le dos, jambes en tablette, bras le long du corps, bas du dos collé au sol.",
           instruction: "Descends une pointe de pied vers le sol puis remonte, sans que le bassin ne bascule.",
           breathing: "Expire à chaque descente.",
           mistake: "Descendre trop bas et perdre le contact des lombaires avec le sol.",
           tips: ["Effleure le sol, ne t’y appuie pas.",
                  "Le genou garde son angle pendant tout le trajet.",
                  "Une main sous les lombaires te dit si tu triches."],
           side: .alternating, neck: true, intensity: 0.8),

        ex("plank-knee-tap", "Planche, genoux alternés", [.deepCore, .lowerAbs],
           family: .antiExtension, pattern: .antiExtension, level: .beginner, motion: .plank,
           setup: "Planche sur les avant-bras, corps aligné, pieds légèrement écartés.",
           instruction: "Descends un genou toucher le sol puis l’autre, sans changer la hauteur du bassin.",
           breathing: "Souffle à chaque appui au sol.",
           mistake: "Faire monter le bassin pour aller chercher le sol plus facilement.",
           tips: ["Le bassin est la seule chose qui ne doit pas bouger.",
                  "Effleure le sol du genou, sans t’y poser.",
                  "Ralentis si les hanches commencent à rouler."],
           side: .alternating, neck: true, intensity: 1.15),

        ex("scissors", "Ciseaux", [.lowerAbs, .deepCore],
           family: .hipFlexion, pattern: .antiExtension, level: .beginner, motion: .scissors,
           setup: "Sur le dos, mains sous les fessiers, jambes tendues à vingt centimètres du sol.",
           instruction: "Croise les jambes tendues à faible amplitude en gardant les lombaires lourdes contre le sol.",
           breathing: "Respire régulièrement, sans bloquer.",
           mistake: "Croiser trop haut : l’amplitude vient des hanches, pas des genoux.",
           tips: ["Plus les jambes sont basses, plus c’est dur : monte-les si le dos tire.",
                  "Les mains sous les fessiers protègent les lombaires.",
                  "Amplitude courte, rythme régulier."],
           neck: true, intensity: 1.15),

        ex("flutter-kicks", "Battements", [.lowerAbs, .deepCore],
           family: .hipFlexion, pattern: .antiExtension, level: .beginner, motion: .flutter,
           setup: "Sur le dos, mains sous les fessiers, jambes tendues et décollées du sol.",
           instruction: "Alterne de petits battements rapides, nombril rentré et bassin parfaitement immobile.",
           breathing: "Expire longuement sur quatre battements.",
           mistake: "Battre avec les genoux fléchis, ce qui décharge complètement les abdos.",
           tips: ["Jambes tendues : c’est la longueur du levier qui fait le travail.",
                  "Le bassin ne se balance pas d’avant en arrière.",
                  "Monte un peu les jambes si le bas du dos décolle."],
           neck: true, intensity: 1.2),

        ex("leg-raise", "Relevé de jambes", [.lowerAbs, .deepCore],
           family: .hipFlexion, pattern: .antiExtension, level: .balanced, motion: .legRaise,
           setup: "Sur le dos, mains sous les fessiers, jambes tendues à quelques centimètres du sol.",
           instruction: "Monte les jambes tendues à la verticale, puis redescends seulement tant que le dos reste plaqué.",
           breathing: "Expire en remontant les jambes.",
           mistake: "Laisser le bas du dos se creuser pendant que les jambes descendent.",
           tips: ["La descente compte plus que la montée : freine-la.",
                  "Arrête la descente à l’endroit exact où le dos décolle.",
                  "Fléchis légèrement les genoux si les ischios te limitent."],
           neck: true, intensity: 1.25),

        ex("bent-knee-raise", "Relevé de genoux", [.lowerAbs, .deepCore],
           family: .hipFlexion, pattern: .antiExtension, level: .beginner, motion: .legRaise,
           setup: "Sur le dos, genoux fléchis à quatre-vingt-dix degrés, tibias parallèles au sol.",
           instruction: "Rapproche les genoux de la poitrine puis reviens, sans jamais prendre d’élan.",
           breathing: "Souffle lorsque les genoux reviennent vers toi.",
           mistake: "Ouvrir l’angle du genou pendant le mouvement, ce qui transforme l’exercice.",
           tips: ["L’angle du genou reste le même du début à la fin.",
                  "Pas d’élan : si tu balances, ralentis.",
                  "C’est la version accessible du relevé de jambes."],
           neck: true, intensity: 0.9),

        ex("bear-hold", "Gainage de l’ours", [.deepCore, .fullCore],
           family: .antiExtension, pattern: .antiExtension, level: .balanced, motion: .bearHold,
           setup: "À quatre pattes, mains sous les épaules, genoux sous les hanches puis décollés de quelques centimètres.",
           instruction: "Tiens les genoux juste au-dessus du sol, dos plat, en poussant fort dans les mains.",
           breathing: "Respire calmement malgré la tension.",
           mistake: "Monter les genoux trop haut, ce qui arrondit le dos et vide l’exercice.",
           tips: ["Deux ou trois centimètres suffisent : plus haut, c’est plus facile.",
                  "Le dos reste assez plat pour y poser un verre.",
                  "Éloigne les épaules des oreilles."],
           neck: true, intensity: 1.2),

        ex("hollow-hold", "Gainage creux", [.deepCore, .lowerAbs],
           family: .antiExtension, pattern: .antiExtension, level: .advanced, motion: .hollowHold,
           setup: "Sur le dos, lombaires écrasées au sol, bras et jambes tendus et décollés.",
           instruction: "Éloigne bras et jambes du sol, mais seulement tant que les lombaires restent collées.",
           breathing: "Expire longuement, côtes fermées.",
           mistake: "Chercher l’amplitude au point de décoller le bas du dos.",
           tips: ["Le dos plaqué est la seule règle : tout le reste s’y adapte.",
                  "Genoux pliés ou bras le long du corps pour alléger.",
                  "Ferme les côtes vers le bassin."],
           neck: true, intensity: 1.5),

        ex("mountain-climber", "Grimpeur", [.fullCore, .lowerAbs],
           family: .locomotion, pattern: .antiExtension, level: .balanced, motion: .mountainClimber,
           impact: .dynamic,
           setup: "Planche haute, épaules à l’aplomb des mains, dos plat, pieds joints.",
           instruction: "Ramène alternativement un genou sous la poitrine en gardant les épaules au-dessus des mains.",
           breathing: "Souffle sur deux appuis.",
           mistake: "Faire rebondir le bassin de haut en bas à chaque appui.",
           tips: ["Les épaules restent au-dessus des mains, elles ne reculent pas.",
                  "Le bassin garde sa hauteur, quelle que soit la vitesse.",
                  "Ralentis plutôt que de casser la ligne."],
           side: .alternating, neck: true, intensity: 1.6),

        ex("plank-jacks", "Planche sautée", [.fullCore, .obliques],
           family: .locomotion, pattern: .antiExtension, level: .advanced, motion: .plank,
           impact: .dynamic,
           setup: "Planche haute ou sur les avant-bras, pieds joints, bassin verrouillé.",
           instruction: "Écarte puis resserre les pieds d’un saut, en gardant le bassin bas et immobile.",
           breathing: "Respire sur un rythme régulier.",
           mistake: "Laisser le bassin osciller de haut en bas à chaque écart.",
           tips: ["Amortis la réception : les sauts doivent être silencieux.",
                  "Le haut du corps ne bouge pas du tout.",
                  "Marche les pieds au lieu de sauter pour la version silencieuse."],
           neck: true, intensity: 1.75)
    ]

    // MARK: - Anti-rotation
    //
    // Refusing a twist while a limb moves. The hardest thing to feel and the
    // easiest to fake, so every cue here is about what must NOT move.

    private static let antiRotation: [Exercise] = [
        ex("bird-dog", "Bird dog", [.deepCore, .lowerBack],
           family: .posterior, pattern: .antiRotation, level: .beginner, motion: .birdDog,
           setup: "À quatre pattes, mains sous les épaules, genoux sous les hanches, nuque longue.",
           instruction: "Allonge le bras et la jambe opposés à l’horizontale, hanches face au sol.",
           breathing: "Expire pendant l’allongement.",
           mistake: "Lever la jambe plus haut que la hanche, ce qui cambre le bas du dos.",
           tips: ["La jambe ne monte pas plus haut que la hanche.",
                  "Imagine un verre d’eau posé sur le bas de ton dos.",
                  "Allonge-toi plutôt que de monter."],
           side: .alternating, neck: true, intensity: 0.8),

        ex("plank-shoulder-tap", "Épaules alternées", [.deepCore, .obliques],
           family: .antiExtension, pattern: .antiRotation, level: .balanced, motion: .bearHold,
           setup: "Planche haute, pieds écartés plus large que le bassin pour élargir l’appui.",
           instruction: "Touche l’épaule opposée d’une main, puis l’autre, sans que le bassin ne tourne.",
           breathing: "Expire à chaque toucher.",
           mistake: "Balancer le bassin d’un côté à l’autre pour libérer la main.",
           tips: ["Écarte les pieds : c’est ce qui rend la position tenable.",
                  "Le bassin reste parallèle au sol pendant tout l’exercice.",
                  "Lent : la vitesse cache la rotation."],
           side: .alternating, neck: true, intensity: 1.4),

        ex("plank-reach", "Planche bras tendu", [.deepCore, .fullCore],
           family: .antiExtension, pattern: .antiRotation, level: .advanced, motion: .plankReach,
           setup: "Planche haute, pieds un peu écartés pour élargir l’appui.",
           instruction: "Tends un bras droit devant toi et tiens-le, sans laisser le bassin pivoter.",
           breathing: "Expire lorsque le bras s’allonge.",
           mistake: "Laisser le bassin pivoter au moment où le bras quitte le sol.",
           tips: ["Transfère le poids avant de lever la main, pas après.",
                  "Le bras monte à hauteur d’oreille, pas plus.",
                  "Si tu bascules, écarte davantage les pieds."],
           side: .alternating, neck: true, intensity: 1.5),

        ex("bear-shoulder-tap", "Ours, épaules alternées", [.deepCore, .obliques],
           family: .antiExtension, pattern: .antiRotation, level: .advanced, motion: .bearHold,
           setup: "Position de l’ours stable, genoux à quelques centimètres du sol.",
           instruction: "Touche l’épaule opposée sans que les genoux ne redescendent ni que le bassin ne roule.",
           breathing: "Expire lors de chaque toucher.",
           mistake: "Laisser le bassin rouler d’un côté à l’autre à chaque toucher.",
           tips: ["Les genoux restent décollés : c’est la moitié de l’exercice.",
                  "Un toucher lent vaut trois touchers rapides.",
                  "Repose les genoux plutôt que de perdre le dos plat."],
           side: .alternating, neck: true, intensity: 1.45),

        ex("cross-climber", "Grimpeur croisé", [.obliques, .fullCore],
           family: .rotation, pattern: .antiRotation, level: .advanced, motion: .mountainClimber,
           impact: .dynamic,
           setup: "Planche haute, appuis stables, regard légèrement en avant des mains.",
           instruction: "Dirige chaque genou vers le coude opposé tout en gardant le haut du corps stable.",
           breathing: "Expire sur chaque diagonale.",
           mistake: "Tourner les épaules pour aller chercher le coude, au lieu de faire travailler les obliques.",
           tips: ["Ce sont les hanches qui tournent, pas les épaules.",
                  "Le genou passe sous le corps, pas sur le côté.",
                  "Garde le bassin bas pendant tout le trajet."],
           side: .alternating, neck: true, intensity: 1.7),

        ex("bridge-march", "Marche en pont", [.deepCore, .lowerBack],
           family: .posterior, pattern: .antiRotation, level: .advanced, motion: .bridgeMarch,
           setup: "Bassin déjà monté et stable, appuis fermes sur les deux pieds.",
           instruction: "Décolle un pied puis l’autre sans laisser une hanche descendre.",
           breathing: "Expire sur chaque marche.",
           mistake: "Laisser la hanche du côté libre tomber dès que le pied décolle.",
           tips: ["Le bassin reste à la même hauteur, des deux côtés.",
                  "Décolle à peine le pied : deux centimètres suffisent.",
                  "Serre le fessier de la jambe qui reste au sol."],
           side: .alternating, neck: true, intensity: 1.25)
    ]

    // MARK: - Anti-lateral flexion
    //
    // The thinnest group in the catalog: two movements, both held on one side
    // for a whole interval, neither accessible to a complete beginner. The
    // engine treats covering this pattern as a bonus rather than a requirement
    // for exactly that reason.

    private static let antiLateralFlexion: [Exercise] = [
        ex("side-plank", "Planche latérale", [.obliques, .deepCore],
           family: .lateral, pattern: .antiLateralFlexion, level: .balanced, motion: .sidePlank,
           setup: "Sur le côté, coude à l’aplomb de l’épaule, pieds superposés, bassin décollé.",
           instruction: "Aligne épaules, bassin et pieds, pousse le sol avec le coude et garde la taille haute.",
           breathing: "Respire lentement dans les côtes du dessus.",
           mistake: "Laisser le bassin descendre ou le buste basculer vers l’avant.",
           tips: ["Pousse le sol : ne te repose pas sur l’épaule.",
                  "Le genou du dessous au sol allège nettement la position.",
                  "Les deux côtés se travaillent, l’un après l’autre."],
           side: .heldPerSide, neck: true, intensity: 1.3),

        ex("side-plank-dip", "Planche latérale, bassin", [.obliques, .deepCore],
           family: .lateral, pattern: .antiLateralFlexion, level: .advanced, motion: .sidePlank,
           setup: "Position de planche latérale stable, main libre posée sur la hanche.",
           instruction: "Abaisse le bassin de quelques centimètres puis remonte, sans que le buste ne tourne.",
           breathing: "Expire à la remontée.",
           mistake: "Tourner le buste vers le sol pendant la descente.",
           tips: ["Descends peu : l’amplitude n’est pas ce qui fait l’exercice.",
                  "Le buste reste de profil du début à la fin.",
                  "Remonte plus haut que l’alignement pour finir le mouvement."],
           side: .heldPerSide, neck: true, intensity: 1.5)
    ]

    // MARK: - Dynamic flexion
    //
    // Actively shortening the abdominal wall. The most familiar work, and the
    // easiest to over-serve — the engine caps any single pattern at 45 % of a
    // session largely because of this group.

    private static let dynamicFlexion: [Exercise] = [
        ex("classic-crunch", "Crunch contrôlé", [.upperAbs],
           family: .flexion, pattern: .dynamicFlexion, level: .beginner, motion: .crunch,
           setup: "Sur le dos, genoux fléchis, pieds au sol, bras croisés sur la poitrine.",
           instruction: "Décolle les omoplates en rapprochant les côtes du bassin, regard vers le plafond.",
           breathing: "Expire en rapprochant les côtes du bassin.",
           mistake: "Monter en tirant sur la nuque plutôt qu’en fermant les côtes.",
           tips: ["Garde un poing d’écart entre le menton et la poitrine.",
                  "Monter haut ne sert à rien : les omoplates suffisent.",
                  "Bras croisés plutôt que derrière la tête : la nuque ne travaille pas."],
           neck: true, intensity: 0.9),

        ex("reverse-crunch", "Crunch inversé", [.lowerAbs, .deepCore],
           family: .flexion, pattern: .dynamicFlexion, level: .beginner, motion: .reverseCrunch,
           setup: "Sur le dos, genoux ramenés au-dessus des hanches, bras à plat au sol.",
           instruction: "Enroule le bassin vers les côtes en décollant le coccyx, sans lancer les jambes.",
           breathing: "Expire pendant l’enroulement.",
           mistake: "Lancer les jambes derrière la tête au lieu d’enrouler le bassin.",
           tips: ["C’est le coccyx qui décolle, pas les jambes qui partent.",
                  "Deux centimètres d’enroulement suffisent.",
                  "Les mains à plat aident, elles ne poussent pas."],
           neck: true, intensity: 1.0),

        ex("hip-raise", "Relevé de bassin", [.lowerAbs, .deepCore],
           family: .hipFlexion, pattern: .dynamicFlexion, level: .beginner, motion: .hipRaise,
           setup: "Allongé sur le dos, bras le long du corps, paumes au sol, genoux fléchis.",
           instruction: "Ramène les genoux puis décolle doucement le bassin du sol, sans prendre d’élan.",
           breathing: "Expire en montant, inspire en contrôlant la descente.",
           mistake: "Prendre de l’élan avec les jambes au lieu d’enrouler le bassin.",
           tips: ["La descente lente est ce qui fait progresser.",
                  "Les paumes stabilisent, elles ne poussent pas.",
                  "Amplitude courte et propre plutôt que grande et lancée."],
           neck: true, intensity: 1.1),

        ex("heel-taps", "Toucher de talons", [.obliques, .upperAbs],
           family: .lateral, pattern: .dynamicFlexion, level: .beginner, motion: .heelTap,
           setup: "Sur le dos, genoux fléchis, talons près des fessiers, épaules légèrement décollées.",
           instruction: "Glisse une main vers le talon du même côté en pliant le buste sur le côté, puis change.",
           breathing: "Respire sur un rythme régulier.",
           mistake: "Reposer les épaules au sol entre chaque toucher.",
           tips: ["Les épaules restent décollées tout du long.",
                  "C’est un pli latéral, pas une rotation.",
                  "Rapproche les talons si tu n’atteins pas."],
           side: .alternating, intensity: 0.85),

        ex("oblique-crunch", "Crunch oblique alterné", [.obliques, .upperAbs],
           family: .lateral, pattern: .dynamicFlexion, level: .beginner, motion: .obliqueCrunch,
           setup: "Sur le dos, genoux fléchis, bras croisés sur la poitrine.",
           instruction: "Rapproche une côte de la hanche opposée, puis change de côté sans forcer.",
           breathing: "Expire sur chaque diagonale.",
           mistake: "Tourner les épaules à vide au lieu de rapprocher les côtes de la hanche.",
           tips: ["Pense à raccourcir un côté du ventre.",
                  "L’épaule vient vers la hanche, pas vers le genou.",
                  "Marque un temps d’arrêt en haut."],
           side: .alternating, neck: true, intensity: 1.0),

        ex("toe-reach", "Toucher de pointes", [.upperAbs, .deepCore],
           family: .flexion, pattern: .dynamicFlexion, level: .balanced, motion: .toeReach,
           setup: "Sur le dos, jambes tendues à la verticale au-dessus des hanches.",
           instruction: "Décolle les omoplates et tends les mains vers les chevilles, sans tirer la nuque.",
           breathing: "Souffle à chaque montée.",
           mistake: "Monter par à-coups d’épaules au lieu d’enrouler le buste.",
           tips: ["Vise les chevilles, pas les orteils : ça garde le buste enroulé.",
                  "Les jambes restent immobiles, seul le buste monte.",
                  "Fléchis les genoux si les ischios tirent."],
           intensity: 1.1),

        ex("seated-knee-tuck", "Genoux-poitrine assis", [.lowerAbs, .fullCore],
           family: .hipFlexion, pattern: .dynamicFlexion, level: .beginner, motion: .seatedTuck,
           setup: "Assis, mains en appui léger derrière les hanches, pieds décollés du sol.",
           instruction: "Éloigne puis ramène les genoux vers la poitrine en gardant le buste grandi.",
           breathing: "Expire en ramenant les genoux.",
           mistake: "S’asseoir sur le bas du dos au lieu de rester grandi sur les ischions.",
           tips: ["Le buste reste fier : s’il s’effondre, réduis l’amplitude.",
                  "Les mains soulagent, elles ne portent pas.",
                  "Tends moins les jambes pour une version plus facile."],
           neck: true, intensity: 1.15),

        ex("russian-twist", "Rotations russes", [.obliques, .fullCore],
           family: .rotation, pattern: .dynamicFlexion, level: .balanced, motion: .twist,
           setup: "Assis, buste incliné en arrière, talons posés ou décollés, mains jointes devant le sternum.",
           instruction: "Grandis le dos et pivote les côtes d’un côté puis de l’autre, bassin face à toi.",
           breathing: "Souffle au passage du milieu.",
           mistake: "Balancer les bras seuls : ce sont les côtes qui doivent pivoter.",
           tips: ["Les mains suivent le sternum, elles ne le devancent pas.",
                  "Le bassin ne tourne pas, seul le buste tourne.",
                  "Talons au sol pour alléger, décollés pour durcir."],
           side: .alternating, intensity: 1.25),

        ex("bicycle", "Bicyclette", [.obliques, .lowerAbs, .fullCore],
           family: .rotation, pattern: .dynamicFlexion, level: .balanced, motion: .bicycle,
           setup: "Sur le dos, jambes en tablette, bras croisés sur la poitrine.",
           instruction: "Allonge une jambe pendant que l’épaule opposée tourne vers le genou fléchi, en restant fluide.",
           breathing: "Expire à chaque changement de côté.",
           mistake: "Pédaler vite en tournant à vide plutôt qu’en amenant l’épaule.",
           tips: ["C’est l’épaule qui vient vers le genou.",
                  "Lent et ample bat rapide et petit.",
                  "La jambe tendue reste haute si le dos décolle."],
           side: .alternating, neck: true, intensity: 1.45),

        ex("long-lever-crunch", "Crunch bras tendus", [.upperAbs, .deepCore],
           family: .flexion, pattern: .dynamicFlexion, level: .advanced, motion: .longLeverCrunch,
           setup: "Sur le dos, bras tendus près des oreilles, genoux fléchis, pieds au sol.",
           instruction: "Décolle uniquement le haut du dos en gardant les bras collés aux oreilles.",
           breathing: "Expire en montant, inspire en redescendant.",
           mistake: "Laisser les bras avancer devant : ils restent alignés avec la tête.",
           tips: ["Les bras près des oreilles : c’est tout ce qui rend l’exercice dur.",
                  "Amplitude courte, elle est normale ici.",
                  "Si les bras avancent, reviens au crunch classique."],
           intensity: 1.35),

        ex("v-sit", "Maintien en V", [.fullCore, .lowerAbs],
           family: .hipFlexion, pattern: .dynamicFlexion, level: .advanced, motion: .vSit,
           setup: "Assis, en équilibre sur les ischions, buste ouvert et tibias parallèles au sol.",
           instruction: "Tiens l’équilibre sans bouger, poitrine ouverte et bas du dos long.",
           breathing: "Respire sans arrondir davantage le dos.",
           mistake: "Arrondir le dos et se laisser tomber en arrière.",
           tips: ["Poitrine haute : le dos rond termine toujours par une chute.",
                  "Mains le long des cuisses pour la version allégée.",
                  "Tibias parallèles au sol, pas plus haut."],
           neck: true, intensity: 1.45),

        ex("explosive-crunch", "Crunch explosif", [.upperAbs, .fullCore],
           family: .flexion, pattern: .dynamicFlexion, level: .advanced, motion: .crunch,
           impact: .dynamic,
           setup: "Sur le dos, genoux fléchis, bras le long du corps, prêt à monter vite.",
           instruction: "Monte vivement puis freine la descente : la puissance vient des abdos, pas de la nuque.",
           breathing: "Expiration brève et sèche en montant.",
           mistake: "Se laisser retomber au sol : la descente doit rester freinée.",
           tips: ["Vite en haut, lent en bas.",
                  "Le menton reste loin de la poitrine malgré la vitesse.",
                  "Arrête la série dès que la descente n’est plus freinée."],
           intensity: 1.55),

        ex("lower-ab-jumps", "Groupés en planche", [.lowerAbs, .fullCore],
           family: .locomotion, pattern: .dynamicFlexion, level: .advanced, motion: .mountainClimber,
           impact: .dynamic,
           setup: "En position de planche haute, mains sous les épaules, pieds joints.",
           instruction: "Ramène les deux pieds d’un saut près des mains, puis repars en planche avec contrôle.",
           breathing: "Souffle sur chaque retour groupé.",
           mistake: "Laisser le bassin monter en pic à chaque saut.",
           tips: ["Amortis la réception, ne laisse pas les pieds claquer.",
                  "Le bassin ne dépasse jamais la ligne des épaules.",
                  "Marche les pieds plutôt que sauter pour la version silencieuse."],
           intensity: 1.65),

        ex("v-sit-extension", "Extension en V", [.fullCore, .lowerAbs],
           family: .hipFlexion, pattern: .dynamicFlexion, level: .athlete, motion: .vSitExtension,
           setup: "Départ en V compact, mains le long des cuisses, buste ouvert.",
           instruction: "Ouvre les jambes et le buste en même temps, puis reviens compact.",
           breathing: "Expire au retour vers la position compacte.",
           mistake: "Perdre l’équilibre vers l’arrière pendant l’extension.",
           tips: ["Ouvre et referme comme un livre, des deux côtés à la fois.",
                  "Va aussi loin que le dos reste long.",
                  "Reviens toujours plus compact que tu n’es parti."],
           neck: true, intensity: 1.8)
    ]

    // MARK: - Hip extension
    //
    // The counterweight. A session made only of flexion trains one half of the
    // trunk and shortens the other.

    private static let hipExtension: [Exercise] = [
        ex("glute-bridge", "Pont fessier", [.lowerBack, .deepCore],
           family: .posterior, pattern: .hipExtension, level: .beginner, motion: .bridge,
           setup: "Sur le dos, pieds à plat près des fessiers, bras le long du corps.",
           instruction: "Pousse dans les talons et monte le bassin jusqu’à aligner épaules, hanches et genoux.",
           breathing: "Expire en montant.",
           mistake: "Monter en cambrant le bas du dos plutôt qu’en serrant les fessiers.",
           tips: ["Serre les fessiers avant de monter, pas après.",
                  "Arrête-toi à l’alignement : plus haut, c’est le dos qui travaille.",
                  "Pousse dans les talons, pas dans les pointes."],
           neck: true, intensity: 0.75),

        ex("back-extension", "Extensions dorsales", [.lowerBack],
           family: .posterior, pattern: .hipExtension, level: .beginner, motion: .superman,
           setup: "Sur le ventre, bras allongés devant, front tourné vers le sol.",
           instruction: "Décolle la poitrine et les bras du sol en gardant la nuque longue et le regard au sol.",
           breathing: "Expire en montant, sans forcer l’amplitude.",
           mistake: "Lever le menton pour monter plus haut, ce qui casse la nuque.",
           tips: ["Le regard reste au sol pendant tout le mouvement.",
                  "Quelques centimètres suffisent.",
                  "Allonge-toi vers l’avant plutôt que de monter."],
           neck: true, intensity: 0.95),

        ex("superman", "Superman", [.lowerBack, .deepCore],
           family: .posterior, pattern: .hipExtension, level: .beginner, motion: .superman,
           setup: "Sur le ventre, bras allongés devant, jambes tendues, front vers le sol.",
           instruction: "Décolle légèrement bras et jambes en même temps, regard toujours vers le sol.",
           breathing: "Expire en montant, ne force pas l’amplitude.",
           mistake: "Casser la nuque en levant le menton pour gagner de la hauteur.",
           tips: ["Bras et jambes montent ensemble, à la même hauteur.",
                  "Faible amplitude, longue tenue.",
                  "Si le bas du dos pince, redescends."],
           neck: true, intensity: 1.0)
    ]

    private static func ex(
        _ id: String,
        _ name: String,
        _ zones: Set<MuscleZone>,
        family: MovementFamily,
        pattern: CorePattern,
        level: WorkoutDifficulty,
        motion: MotionKind,
        impact: ExerciseImpact = .quiet,
        setup: String,
        instruction: String,
        breathing: String,
        mistake: String,
        tips: [String],
        side: SideMode = .bilateral,
        neck: Bool = false,
        intensity: Double
    ) -> Exercise {
        Exercise(
            id: id,
            name: name,
            zones: zones,
            family: family,
            pattern: pattern,
            minimumDifficulty: level,
            impact: impact,
            motion: motion,
            setup: setup,
            instruction: instruction,
            breathing: breathing,
            mistake: mistake,
            tips: tips,
            sideMode: side,
            neckFriendly: neck,
            intensity: intensity
        )
    }
}

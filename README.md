# Hara

Hara est la réécriture iOS native de [SevenAbs](https://github.com/AlexandreVerhoye/SevenAbs), une web app créée pour rendre l’entraînement quotidien des abdos immédiat. Cette V1 conserve l’idée d’une séance courte sans configuration, puis la pousse beaucoup plus loin avec SwiftUI, SceneKit, SwiftData et un vrai moteur adaptatif.

## Ce que contient la V1

- Un programme du jour stable et immédiatement disponible.
- 36 exercices répartis entre haut/bas des abdos, obliques, gainage profond et lombaires.
- Des séances de 5 à 20 minutes générées à durée exacte.
- Quatre niveaux qui changent la sélection des mouvements, la longueur des intervalles et la fréquence des pauses.
- Des priorités musculaires combinables et des filtres sans saut, nuque sensible et récupération renforcée.
- Un lecteur de séance complet : préparation, chrono fiable, pause, reprise, passage, abandon confirmé, sons et haptique.
- Un mannequin d’exercice entièrement procédural et natif, sans Unity, WebView ni asset propriétaire.
- Des badges 3D quotidiens, des défis mensuels et annuels, des séries et une galerie de récompenses.
- Une progression locale avec graphiques, calendrier d’activité et historique.
- Une persistance hors ligne via SwiftData et des rappels locaux optionnels.
- Dark mode, Dynamic Type, VoiceOver et Reduce Motion.

## Stack

- Swift 6 / SwiftUI
- iOS 17+
- SceneKit pour les médailles, sans AR
- SwiftData
- Swift Charts
- UserNotifications
- Swift Testing
- XcodeGen pour un projet reproductible

## Lancer le projet

Prérequis : Xcode 16+ et [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open Hara.xcodeproj
```

Le bundle identifier par défaut est `com.alexandreverhoye.Hara`. Sélectionnez votre équipe de signature dans Xcode pour lancer l’app sur un iPhone physique.

## Architecture

```text
Hara/
├── App/             état global et navigation
├── Design/          thème, motion et composants communs
├── Domain/          catalogue, modèles et générateur
├── Features/        Aujourd’hui, séance, progression, récompenses, réglages
├── Figure/          rendu du mannequin d’exercice
├── Platform/        notifications, sons et haptique
├── Resources/       icône, couleurs, Info.plist et privacy manifest
└── ThreeD/          squelette, motions et activation musculaire
```

`WorkoutEngine` est déterministe à seed identique. Le seed quotidien combine la date locale et les préférences : le programme ne change pas au moindre re-render, tout en variant le lendemain.

La séance est construite à partir d’une **cadence** — un couple travail/récupération et le nombre de mouvements qui s’enchaînent entre deux pauses — et non d’un budget de secondes dans lequel on découperait ensuite du repos :

```text
durée = mouvements × travail + récupérations × repos + mises en place × 5 s
```

Chaque niveau annonce sa cadence et le générateur ne peut pas la trahir : c’est le temps de travail qui absorbe le reste, jamais la longueur du repos.

| Niveau     | Travail | Récupération | Mouvements par pause |
| ---------- | ------- | ------------ | -------------------- |
| Débutant   | 25–35 s | 28–40 s      | 1                    |
| Équilibré  | 32–42 s | 18–26 s      | 2                    |
| Intense    | 38–48 s | 15–20 s      | 3                    |
| Athlète    | 45–55 s | 12–18 s      | 4                    |

Entre deux mouvements d’un même bloc il n’y a qu’une mise en place de cinq secondes : une porte, pas du repos. Le générateur applique d’abord les contraintes de sécurité, garantit la durée totale à la seconde près, favorise les zones choisies, couvre les cinq fonctions du tronc, évite les familles de mouvements consécutives et répartit les mouvements les plus exigeants au lieu de les empiler.

Le mannequin d’exercice est dessiné en SwiftUI à partir d’un squelette articulé : chaque `MotionKind` est une fonction de pose animée, les zones actives sont matérialisées sur le torse, et Reduce Motion gèle une pose pédagogique. Les médailles, elles, sont de la vraie géométrie SceneKit — un disque extrudé et chanfreiné, matériau métallique physique, environnement réfléchi — parce que ce qui les vend est exactement ce qu’un dégradé ne sait pas imiter : un reflet qui glisse sur du métal courbe quand l’objet tourne.

## Données et confidentialité

Toutes les données restent sur l’appareil. Hara n’intègre ni compte, ni publicité, ni SDK analytique, ni tracking. Les notifications sont facultatives et demandées uniquement depuis les réglages.

## Tests

```bash
xcodebuild test \
  -project Hara.xcodeproj \
  -scheme Hara \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Les tests couvrent le catalogue, le déterminisme, les contraintes, la durée exacte, la diversité, la couverture musculaire et la variation réelle entre difficultés.

## Avertissement

Hara est une app de remise en forme et ne remplace pas un avis médical. Arrêtez tout mouvement en cas de douleur inhabituelle et demandez conseil à un professionnel de santé si nécessaire.


# FastAbs

FastAbs est la réécriture iOS native de [SevenAbs](https://github.com/AlexandreVerhoye/SevenAbs), une web app créée pour rendre l’entraînement quotidien des abdos immédiat. Cette V1 conserve l’idée d’une séance courte sans configuration, puis la pousse beaucoup plus loin avec SwiftUI, RealityKit, SwiftData et un vrai moteur adaptatif.

## Ce que contient la V1

- Un programme du jour stable et immédiatement disponible.
- 36 exercices répartis entre haut/bas des abdos, obliques, gainage profond et lombaires.
- Des séances de 5 à 20 minutes générées à durée exacte.
- Quatre niveaux qui changent réellement la sélection des mouvements.
- Des priorités musculaires combinables et des filtres sans saut, nuque sensible et récupération renforcée.
- Un lecteur de séance complet : préparation, chrono fiable, pause, reprise, passage, abandon confirmé, sons et haptique.
- Un coach 3D entièrement procédural et natif, sans Unity, WebView ni asset propriétaire.
- Des badges 3D quotidiens, des défis mensuels et annuels, des séries et une galerie de récompenses.
- Une progression locale avec graphiques, calendrier d’activité et historique.
- Une persistance hors ligne via SwiftData et des rappels locaux optionnels.
- Dark mode, Dynamic Type, VoiceOver et Reduce Motion.

## Stack

- Swift 6 / SwiftUI
- iOS 17+
- RealityKit en mode non-AR
- SwiftData
- Swift Charts
- UserNotifications
- Swift Testing
- XcodeGen pour un projet reproductible

## Lancer le projet

Prérequis : Xcode 16+ et [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```bash
xcodegen generate
open FastAbs.xcodeproj
```

Le bundle identifier par défaut est `com.alexandreverhoye.FastAbs`. Sélectionnez votre équipe de signature dans Xcode pour lancer l’app sur un iPhone physique.

## Architecture

```text
FastAbs/
├── App/             état global et navigation
├── Design/          thème et composants communs
├── Domain/          catalogue, modèles et générateur
├── Features/        Aujourd’hui, séance, progression, récompenses, réglages
├── Platform/        notifications, sons et haptique
├── Resources/       icône, couleurs, Info.plist et privacy manifest
└── ThreeD/          mannequin, motions et badges RealityKit
```

`WorkoutEngine` est déterministe à seed identique. Le seed quotidien combine la date locale et les préférences : le programme ne change pas au moindre re-render, tout en variant le lendemain. Le générateur applique d’abord les contraintes de sécurité, garantit la durée totale, favorise les zones choisies, couvre le centre complet et évite les familles de mouvements consécutives.

Le rendu 3D construit un mannequin articulé avec les primitives PBR de RealityKit. Chaque `MotionKind` est une fonction de pose animée; les zones actives sont matérialisées sur le torse, et Reduce Motion gèle une pose pédagogique.

## Données et confidentialité

Toutes les données restent sur l’appareil. FastAbs n’intègre ni compte, ni publicité, ni SDK analytique, ni tracking. Les notifications sont facultatives et demandées uniquement depuis les réglages.

## Tests

```bash
xcodebuild test \
  -project FastAbs.xcodeproj \
  -scheme FastAbs \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro'
```

Les tests couvrent le catalogue, le déterminisme, les contraintes, la durée exacte, la diversité, la couverture musculaire et la variation réelle entre difficultés.

## Avertissement

FastAbs est une app de remise en forme et ne remplace pas un avis médical. Arrêtez tout mouvement en cas de douleur inhabituelle et demandez conseil à un professionnel de santé si nécessaire.


# Hara

Hara est la réécriture iOS native de [SevenAbs](https://github.com/AlexandreVerhoye/SevenAbs), une web app créée pour rendre l’entraînement quotidien des abdos immédiat. Cette V1 conserve l’idée d’une séance courte sans configuration, puis la pousse beaucoup plus loin avec SwiftUI, SceneKit, SwiftData et un vrai moteur adaptatif.

## Ce que contient la V1

- Une mise en route en trois questions — zones du corps, durée, niveau — qui se termine sur la séance qu'elles produisent, pas sur une promesse.
- Un programme du jour stable et immédiatement disponible.
- 64 exercices : sangle abdominale, haut du corps, bas du corps et mouvements complets, tous au poids du corps avec un tapis pour seul matériel.
- Trois zones du corps activables dans les réglages, que le coach respecte à la lettre.
- Des séances de 5 à 20 minutes générées à durée exacte.
- Quatre niveaux qui changent la sélection des mouvements, la longueur des intervalles et la fréquence des pauses.
- Des priorités musculaires combinables et des filtres sans saut, nuque sensible et récupération renforcée.
- Des playlists prêtes à lancer, dont bas du corps, haut du corps, corps entier et cardio.
- Un lecteur de séance complet : préparation, chrono fiable, pause, reprise, passage, abandon confirmé, sons et haptique.
- Un mannequin d’exercice entièrement procédural et natif, sans Unity, WebView ni asset propriétaire.
- Des badges 3D quotidiens, des défis mensuels et annuels, des séries et une galerie de récompenses.
- Une progression locale avec graphiques, calendrier d’activité et historique.
- Une persistance hors ligne via SwiftData et des rappels locaux optionnels.
- Dark mode, Dynamic Type, VoiceOver et Reduce Motion.

## Stack

- Swift 6 / SwiftUI
- iOS 18+
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

### Zones du corps

Les réglages exposent trois zones — **abdos et gainage**, **haut du corps**, **bas du corps**. Chaque groupe musculaire appartient à exactement une zone, et chaque exercice hérite de ses zones de ses groupes : les deux ne peuvent pas se contredire.

La règle d’éligibilité est un sous-ensemble, pas une intersection : un mouvement n’est programmé que si **toutes** ses zones sont activées. Un burpee travaille les pectoraux que vous soyez venu pour eux ou non, donc désactiver le haut du corps le fait disparaître. Une règle plus permissive rendrait discrètement le travail que l’utilisateur vient de refuser.

Désactiver une zone est une petite instruction et le reste doit le rester. Durée, niveau, rythme, contraintes et exclusions sont conservés tels quels, ainsi que toute priorité encore atteignable ; seule une priorité devenue impossible est retirée, et seulement si elle laisse le champ vide la priorité neutre reprend la main. Reconstruire les préférences depuis les valeurs par défaut serait la solution facile et la mauvaise : elle jetterait une dizaine de décisions pour en appliquer une.

Il reste toujours une zone active : ne rien travailler n’est pas une préférence d’entraînement.

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

Entre deux mouvements d’un même bloc il n’y a qu’une mise en place de cinq secondes : une porte, pas du repos. Le générateur applique d’abord les contraintes de sécurité, garantit la durée totale à la seconde près, favorise les zones choisies, évite les familles de mouvements consécutives et répartit les mouvements les plus exigeants au lieu de les empiler.

La couverture se lit à deux échelles. La séance touche **chaque zone du corps activée** — c’est la promesse la plus visible, et sans elle une séance tirée d’un catalogue majoritairement abdominal n’atteindrait jamais les jambes. À l’intérieur du tronc, elle fait tourner les **cinq fonctions** (anti-extension, anti-rotation, anti-inclinaison, flexion dynamique, extension de hanche), proportionnellement au nombre de mouvements de gainage que la séance contient réellement : promettre cinq fonctions à une séance qui n’a que trois créneaux de tronc serait une promesse d’arithmétique, pas d’entraînement.

Les mouvements composés — burpee, squat thrust — sont animés en images-clés plutôt qu’en déformations d’une posture unique, avec un espacement proportionnel à la distance réellement parcourue entre deux clés : une répartition écrite à la main donne la même tranche de cycle à chaque segment quel qu’en soit le contenu, et le segment le plus long se met alors à sauter.

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


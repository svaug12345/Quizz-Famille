# Quiz'Vacances

Le quiz famille des souvenirs de vacances. Pendant le séjour, chacun glisse ses questions dans une « boîte » scellée ; au retour, la boîte s'ouvre et on joue tous ensemble, en se passant le téléphone.

Version **0.1.1** · Flutter (Android + web) · charte **SV**

---

## Ce que fait la v0.1.0

- **Voyages** : créer une boîte à souvenirs (titre + emoji), la rejoindre depuis un autre téléphone avec un code à 6 caractères (ou son QR code).
- **Profils** : chaque membre a son avatar, sa couleur et un code secret facultatif. Un même téléphone peut porter plusieurs profils.
- **5 formes de questions** : choix multiples, vrai/faux, photo mystère (floue puis nette, bonus si on trouve vite), « qui a dit ça ? », estimation (le plus proche gagne).
- **Qui peut répondre** : tout le monde, ou une sélection de profils. On peut ajouter un profil à la volée. L'auteur ne répond jamais à sa propre question.
- **Secret** : une question déposée ne peut plus être relue. On ne voit que le nombre de souvenirs de chacun. Bouton « ANNULER » pendant quelques secondes pour corriger une erreur.
- **Quiz** : un téléphone qui tourne, en mode « un joueur par question » ou « tout le monde répond », dans l'ordre des jours ou mélangé. Podium à la fin.
- **Carnet de souvenirs** : après le quiz, toutes les questions jour par jour, avec photos et réponses.
- **Hors ligne** : les souvenirs (photos comprises) déposés sans réseau partent tout seuls dès que ça capte. Ouvrir la boîte et lancer le quiz demandent du réseau.

---

## 1. Lancer le projet (mode démo)

Les dossiers `android/` et `web/` sont déjà dans le dépôt (générés par `flutter create`, libellé « Quiz’Vacances » déjà en place) :

```bash
cd Bureau\Projets\android
git clone https://github.com/svaug12345/quizz-famille
cd quizz-famille
flutter pub get
flutter run -d chrome
```

Sans Firebase, l'appli démarre en **mode démo** (bandeau en haut de l'accueil) : tout fonctionne, mais sur un seul téléphone.

Vérifier le code et lancer les tests automatiques :

```bash
flutter analyze
flutter test
```

(Dans les libellés `android:label` et `web/manifest.json`, on utilise l'apostrophe typographique `’` : l'apostrophe droite poserait problème dans le XML.)

---

## 2. Brancher Firebase (plusieurs téléphones)

Gratuit, sans carte bancaire (offre Spark).

1. **Créer le projet** sur [console.firebase.google.com](https://console.firebase.google.com) → « Ajouter un projet » → `quiz-vacances`.
2. **Authentication** → Commencer → Méthodes de connexion → activer **Anonyme**.
3. **Firestore Database** → Créer une base → mode **production** → région `europe-west9 (Paris)`.
4. **Règles** : onglet « Règles » de Firestore → coller le contenu de `firestore.rules` → Publier.
5. **Relier l'appli** (une seule fois, depuis le dossier du projet) :

```bash
dart pub global activate flutterfire_cli
firebase login
flutterfire configure --project=quiz-vacances --platforms=android,web
```

Cette commande remplace `lib/firebase_options.dart` (le fichier provisoire) par le vrai. Relance l'appli : le bandeau « mode démo » disparaît.

> Il faut avoir installé l'outil `firebase` (Firebase CLI) : `npm install -g firebase-tools`.

### Comment le secret est garanti

Ce n'est pas l'appli qui cache les questions, ce sont **les règles Firestore** : le serveur refuse toute lecture d'une question tant que le voyage est au statut `collecte`. Même en bidouillant l'appli, impossible de tricher. Les photos sont rangées dans la question elle-même, donc protégées de la même façon.

---

## 3. Organisation du code

```
lib/
├── main.dart                  Démarrage : Firebase ou mode démo, logo SV animé
├── firebase_options.dart      Provisoire, remplacé par flutterfire configure
├── models/models.dart         Profile, Trip, Question, QuizResult
├── data/
│   ├── repository.dart        Le « contrat » + mémoire locale du téléphone
│   ├── firebase_repository.dart   Moteur partagé (Firestore)
│   └── demo_repository.dart   Moteur un seul téléphone
├── theme/sv_theme.dart        Charte SV → thème Flutter (clair + sombre)
├── widgets/
│   ├── common.dart            Avatars, photo, « qui peut répondre », code secret
│   └── sv_mark_path.dart      Tracé du logo SV (le geste)
└── screens/
    ├── home_screen.dart       Liste des voyages
    ├── create_trip_screen.dart
    ├── join_trip_screen.dart
    ├── trip_screen.dart       Boîte scellée / boîte ouverte
    ├── add_question_screen.dart
    ├── quiz_setup_screen.dart
    ├── quiz_play_screen.dart  Le jeu, téléphone qui tourne
    ├── results_screen.dart    Podium
    └── memories_screen.dart   Carnet de souvenirs
```

---

## 4. Mettre à jour la version

À chaque modification, augmenter **les deux** :

- `version:` dans `pubspec.yaml` (ex. `0.1.1+2`)
- `kAppVersion` dans `lib/main.dart` (ex. `'0.1.1'`)

---

## Idées pour la suite

- Scanner le QR code d'invitation directement dans l'appli
- Son mystère (5 secondes enregistrées sur le moment)
- « Où était-on ? » : placer un point sur une carte
- Remettre les moments de la journée dans l'ordre
- Afficher le quiz sur l'écran M7 du salon
- Icône d'appli SV (le geste en petit, coin bas-droit)

# Quiz'Vacances — consignes pour Claude Code

Appli Flutter (Android + web) de Sébastien : quiz famille sur les souvenirs de vacances. Voir README.md pour le fonctionnement et l'architecture.

## État du projet

- v0.1.0 écrite dans une session claude.ai **sans compilateur** (pub.dev inaccessible) : jamais passée par `flutter analyze`.
- Les dossiers `android/` et `web/` n'existent pas encore. Les générer avec :
  `flutter create --org com.svaug --project-name quiz_vacances --platforms android,web .`
- Point d'API incertain : `AppBarThemeData` / `InputDecorationThemeData` dans `lib/theme/sv_theme.dart` (revenir à `AppBarTheme` / `InputDecorationTheme` si l'analyseur les refuse).
- Firebase pas encore branché : `lib/firebase_options.dart` est un fichier provisoire → l'appli tourne en mode démo (un seul téléphone).

## Conventions (à respecter à chaque modification)

- **Code très commenté, en français** : Sébastien apprend en lisant le code. Expliquer le pourquoi, pas seulement le quoi.
- **Augmenter la version à chaque mise à jour**, aux deux endroits : `version:` dans `pubspec.yaml` (ex. `0.1.1+2`) et `kAppVersion` dans `lib/main.dart`.
- **Charte SV** : couleurs et polices uniquement via `lib/theme/sv_theme.dart` (`context.sv.*`, `svScore`). Ton : phrases courtes, tutoiement, boutons en capitales.
- **Secret des questions** : garanti par `firestore.rules` (lecture des questions refusée tant que `status == 'collecte'`). Toute nouvelle écriture Firestore doit rester autorisée par ces règles : les mettre à jour en même temps.
- Les écrans passent toujours par `QuizRepository` (jamais Firebase en direct), pour que le mode démo continue de marcher.
- Expliquer à Sébastien, dans la réponse, ce qui a été changé et pourquoi.

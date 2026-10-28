# Quiz'Vacances — consignes pour Claude Code

Appli Flutter (Android + web) de Sébastien : quiz famille sur les souvenirs de vacances. Voir README.md pour le fonctionnement et l'architecture.

## État du projet

- v0.1.1 : `android/` et `web/` générés, `flutter analyze` sans aucun problème, `flutter test` OK, parcours complet testé dans Chrome en mode démo (Flutter 3.47).
- `google_fonts` est épinglé en `^8.0.0` : la 9.0 passe par le paquet `material_ui`, dont le `TextTheme` est incompatible avec celui de `package:flutter/material.dart`.
- Lancer en web : `flutter run -d chrome` (ou `-d web-server --web-port 8080 --release` ; le mode debug en web-server reste bloqué en attente du débogueur).
- Firebase pas encore branché : `lib/firebase_options.dart` est un fichier provisoire → l'appli tourne en mode démo (un seul téléphone).

## Conventions (à respecter à chaque modification)

- **Code très commenté, en français** : Sébastien apprend en lisant le code. Expliquer le pourquoi, pas seulement le quoi.
- **Augmenter la version à chaque mise à jour**, aux deux endroits : `version:` dans `pubspec.yaml` (ex. `0.1.1+2`) et `kAppVersion` dans `lib/main.dart`.
- **Charte SV** : couleurs et polices uniquement via `lib/theme/sv_theme.dart` (`context.sv.*`, `svScore`). Ton : phrases courtes, tutoiement, boutons en capitales.
- **Secret des questions** : garanti par `firestore.rules` (lecture des questions refusée tant que `status == 'collecte'`). Toute nouvelle écriture Firestore doit rester autorisée par ces règles : les mettre à jour en même temps.
- Les écrans passent toujours par `QuizRepository` (jamais Firebase en direct), pour que le mode démo continue de marcher.
- Expliquer à Sébastien, dans la réponse, ce qui a été changé et pourquoi.

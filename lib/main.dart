// =============================================================================
// main.dart — Point d'entrée de Quiz'Vacances
// -----------------------------------------------------------------------------
// Au démarrage :
//   1. on charge la mémoire locale du téléphone (DeviceState) ;
//   2. on essaie de brancher Firebase :
//        - configuré  → mode partagé (plusieurs téléphones) ;
//        - pas encore → mode démo (tout reste sur ce téléphone) ;
//   3. on affiche l'écran de lancement (le geste SV se dessine), puis l'accueil.
// =============================================================================

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import 'data/demo_repository.dart';
import 'data/firebase_repository.dart';
import 'data/repository.dart';
import 'firebase_options.dart';
import 'screens/home_screen.dart';
import 'theme/sv_theme.dart';
import 'widgets/common.dart';

/// Numéro de version affiché dans l'appli.
/// ⚠️ À augmenter à chaque mise à jour, en même temps que « version: » dans pubspec.yaml.
const kAppVersion = '0.1.1';

Future<void> main() async {
  // Obligatoire avant tout appel « natif » (préférences, Firebase…) avant runApp.
  WidgetsFlutterBinding.ensureInitialized();
  final device = await DeviceState.load();
  runApp(QuizVacancesApp(device: device));
}

class QuizVacancesApp extends StatefulWidget {
  const QuizVacancesApp({super.key, required this.device});
  final DeviceState device;

  @override
  State<QuizVacancesApp> createState() => _QuizVacancesAppState();
}

class _QuizVacancesAppState extends State<QuizVacancesApp> {
  /// Le moteur de données, choisi par _Bootstrap au démarrage.
  QuizRepository? _repo;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: "Quiz'Vacances",
      debugShowCheckedModeBanner: false,
      theme: buildSvTheme(Brightness.light),
      darkTheme: buildSvTheme(Brightness.dark),
      themeMode: ThemeMode.system, // suit le réglage clair/sombre du téléphone
      // « builder » enveloppe le Navigator tout entier : AppScope placé ici
      // est donc visible depuis TOUS les écrans, y compris ceux ouverts
      // ensuite avec Navigator.push (qui ne sont pas « dans » l'accueil).
      builder: (context, child) => _repo == null
          ? child!
          : AppScope(repo: _repo!, device: widget.device, child: child!),
      home: _Bootstrap(
        device: widget.device,
        onReady: (repo) => setState(() => _repo = repo),
      ),
    );
  }
}

/// Écran de démarrage : prépare les données pendant que le logo se dessine.
class _Bootstrap extends StatefulWidget {
  const _Bootstrap({required this.device, required this.onReady});
  final DeviceState device;
  final ValueChanged<QuizRepository> onReady;

  @override
  State<_Bootstrap> createState() => _BootstrapState();
}

class _BootstrapState extends State<_Bootstrap> with SingleTickerProviderStateMixin {
  // L'AnimationController fait varier une valeur de 0 à 1 en 900 ms :
  // on s'en sert pour dessiner le geste de gauche à droite.
  late final AnimationController _anim = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  /// Chronomètre lancé à l'ouverture, pour la durée minimale du logo.
  final _clock = Stopwatch()..start();

  bool _ready = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    setState(() => _error = null);
    QuizRepository repo;

    // Étape 1 : Firebase est-il configuré ?
    bool firebaseReady;
    try {
      // Tant que « flutterfire configure » n'a pas été lancé, le fichier
      // firebase_options.dart provisoire lève une erreur → mode démo.
      // (Firebase.apps non vide = déjà initialisé lors d'un essai précédent.)
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
      }
      firebaseReady = true;
    } catch (_) {
      firebaseReady = false;
    }

    if (firebaseReady) {
      // Étape 2 : connexion anonyme. Il faut du réseau au tout premier lancement.
      try {
        await FirebaseRepository.signIn();
        repo = FirebaseRepository(widget.device);
      } catch (e) {
        if (!mounted) return;
        setState(() => _error =
            'Connexion impossible. Au premier lancement, il faut du réseau.');
        return;
      }
    } else {
      repo = DemoRepository(widget.device);
    }

    // On laisse le logo affiché au moins ~1,2 s au total (charte SV),
    // même si Firebase a répondu très vite.
    final remaining = 1200 - _clock.elapsedMilliseconds;
    if (remaining > 0) {
      await Future<void>.delayed(Duration(milliseconds: remaining));
    }
    if (!mounted) return;
    widget.onReady(repo); // AppScope se met en place au-dessus du Navigator
    setState(() => _ready = true);
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_ready) return const HomeScreen();

    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _anim,
              builder: (context, _) =>
                  SvMark(size: 120, color: context.sv.ink, reveal: _anim.value),
            ),
            if (_error != null) ...[
              const SizedBox(height: 32),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 32),
                child: Text(_error!, textAlign: TextAlign.center),
              ),
              const SizedBox(height: 16),
              FilledButton(onPressed: _start, child: const Text('RÉESSAYER')),
            ],
          ],
        ),
      ),
    );
  }
}

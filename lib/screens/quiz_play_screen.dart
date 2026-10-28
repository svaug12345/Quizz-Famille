// =============================================================================
// quiz_play_screen.dart — Le quiz, avec UN téléphone qui tourne
// -----------------------------------------------------------------------------
// Chaque question suit 3 phases :
//   1. PASSAGE  : « Passe le téléphone à Gaby » (la question reste cachée) ;
//   2. RÉPONSE  : le joueur répond ;
//      (en mode « tout le monde », on repasse le téléphone au suivant)
//   3. RÉVÉLATION : la bonne réponse, qui a trouvé, l'auteur du souvenir.
//
// Points : 1 par bonne réponse.
//   + 1 bonus « photo mystère » si on trouve avant que la photo soit à moitié nette ;
//   estimation : le plus proche gagne (seul : à 10 % près).
// =============================================================================

import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../models/models.dart';
import '../theme/sv_theme.dart';
import '../widgets/common.dart';
import 'results_screen.dart';

/// Les deux façons de jouer.
enum QuizMode { unParQuestion, toutLeMonde }

extension QuizModeInfo on QuizMode {
  String get label => switch (this) {
        QuizMode.unParQuestion => 'Un joueur par question',
        QuizMode.toutLeMonde => 'Tout le monde répond',
      };
  String get hint => switch (this) {
        QuizMode.unParQuestion => 'Chacun son tour, rapide et rythmé.',
        QuizMode.toutLeMonde => 'Le téléphone fait le tour à chaque question, réponses secrètes.',
      };
}

/// Une « manche » : une question + les joueurs qui vont y répondre.
class _Turn {
  _Turn(this.question, this.answerers);
  final Question question;
  final List<Profile> answerers;
}

enum _Phase { passage, reponse, revelation }

/// Flou maximal de la photo mystère (en pixels de flou gaussien).
const double _maxBlur = 18;

class QuizPlayScreen extends StatefulWidget {
  const QuizPlayScreen({
    super.key,
    required this.trip,
    required this.questions,
    required this.players,
    required this.mode,
    required this.shuffle,
  });

  final Trip trip;
  final List<Question> questions;
  final List<Profile> players;
  final QuizMode mode;
  final bool shuffle;

  @override
  State<QuizPlayScreen> createState() => _QuizPlayScreenState();
}

class _QuizPlayScreenState extends State<QuizPlayScreen> with SingleTickerProviderStateMixin {
  late final List<_Turn> _turns = _buildTurns();
  int _turnIndex = 0;
  int _answererIndex = 0; // quel joueur de la manche répond en ce moment
  _Phase _phase = _Phase.passage;

  /// Réponses de la manche en cours : profilId → réponse
  /// (int pour un choix, bool pour vrai/faux, String pour un profil, double pour un nombre).
  final Map<String, Object> _answers = {};

  /// Pour la photo mystère : le flou restant au moment de la réponse.
  final Map<String, double> _blurAtAnswer = {};

  /// Points gagnés pendant la manche (pour la révélation).
  Map<String, int> _turnPoints = {};

  /// Scores cumulés de la partie.
  late final Map<String, int> _scores = {for (final p in widget.players) p.id: 0};

  /// Animation du flou : de _maxBlur à 0 en 12 secondes.
  late final AnimationController _blur = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  final _numberField = TextEditingController();

  @override
  void dispose() {
    _blur.dispose();
    _numberField.dispose();
    super.dispose();
  }

  _Turn get _turn => _turns[_turnIndex];
  Profile get _currentPlayer => _turn.answerers[_answererIndex];

  // ---------------------------------------------------------------------------
  // Préparation : quelle question, pour qui ?
  // ---------------------------------------------------------------------------
  List<_Turn> _buildTurns() {
    final questions = [...widget.questions];
    if (widget.shuffle) {
      questions.shuffle(Random());
    } else {
      questions.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    }

    // Combien de questions chaque joueur a déjà reçues (mode un par question).
    final given = {for (final p in widget.players) p.id: 0};
    var rotation = 0; // pour départager équitablement les égalités
    final turns = <_Turn>[];

    for (final q in questions) {
      final eligible = widget.players.where((p) => q.canAnswer(p.id)).toList();
      if (eligible.isEmpty) continue; // personne de présent ne peut répondre

      if (widget.mode == QuizMode.toutLeMonde) {
        turns.add(_Turn(q, eligible));
      } else {
        // On donne la question au joueur éligible qui en a eu le moins.
        // En cas d'égalité, on tourne dans l'ordre de la liste des joueurs.
        eligible.sort((a, b) {
          final byCount = given[a.id]!.compareTo(given[b.id]!);
          if (byCount != 0) return byCount;
          int pos(Profile p) =>
              (widget.players.indexOf(p) - rotation) % widget.players.length;
          return pos(a).compareTo(pos(b));
        });
        final chosen = eligible.first;
        given[chosen.id] = given[chosen.id]! + 1;
        rotation = widget.players.indexOf(chosen) + 1;
        turns.add(_Turn(q, [chosen]));
      }
    }
    return turns;
  }

  // ---------------------------------------------------------------------------
  // Déroulement
  // ---------------------------------------------------------------------------
  // Les « if (_phase != …) return; » ci-dessous protègent des doubles appuis
  // pendant le fondu entre deux phases (l'ancien écran reste touchable 250 ms).
  void _showQuestion() {
    if (_phase != _Phase.passage) return;
    setState(() => _phase = _Phase.reponse);
    _numberField.clear();
    if (_turn.question.type == QuestionType.photoFloue) {
      _blur.forward(from: 0); // la photo commence floue et se dévoile
    }
  }

  void _answer(Object value) {
    if (_phase != _Phase.reponse) return;
    HapticFeedback.selectionClick(); // petite vibration de confirmation
    _answers[_currentPlayer.id] = value;
    _blurAtAnswer[_currentPlayer.id] = _maxBlur * (1 - _blur.value);
    _blur.stop();

    if (_answererIndex < _turn.answerers.length - 1) {
      // Au suivant : on repasse le téléphone, la question se recache.
      setState(() {
        _answererIndex++;
        _phase = _Phase.passage;
      });
    } else {
      _scoreTurn();
      setState(() => _phase = _Phase.revelation);
    }
  }

  /// Calcule les points de la manche.
  void _scoreTurn() {
    final q = _turn.question;
    final points = <String, int>{for (final p in _turn.answerers) p.id: 0};

    if (q.type == QuestionType.estimation) {
      final target = q.correctNumber ?? 0;
      double diff(String id) => ((_answers[id] as double) - target).abs();

      if (_turn.answerers.length == 1) {
        // Seul : gagné si on est à 10 % près (ou à 1 près pour les petits nombres).
        final id = _turn.answerers.first.id;
        if (diff(id) <= max(1.0, target.abs() * 0.1)) points[id] = 1;
      } else {
        // À plusieurs : le ou les plus proches gagnent.
        final best = _turn.answerers.map((p) => diff(p.id)).reduce(min);
        for (final p in _turn.answerers) {
          if (diff(p.id) == best) points[p.id] = 1;
        }
      }
    } else {
      for (final p in _turn.answerers) {
        if (_isCorrect(q, _answers[p.id])) {
          points[p.id] = 1;
          // Bonus photo mystère : trouvé alors que la photo était encore très floue.
          if (q.type == QuestionType.photoFloue && (_blurAtAnswer[p.id] ?? 0) > _maxBlur / 2) {
            points[p.id] = 2;
          }
        }
      }
    }

    points.forEach((id, pts) => _scores[id] = (_scores[id] ?? 0) + pts);
    _turnPoints = points;
  }

  bool _isCorrect(Question q, Object? a) => switch (q.type) {
        QuestionType.qcm || QuestionType.photoFloue => a == q.correctIndex,
        QuestionType.vraiFaux => a == q.correctBool,
        QuestionType.quiADit => a == q.correctProfileId,
        QuestionType.estimation => false, // géré à part
      };

  /// Texte d'une réponse donnée, pour la révélation.
  String _answerLabel(Question q, Object? a) {
    if (a == null) return '—';
    return switch (q.type) {
      QuestionType.qcm || QuestionType.photoFloue => q.choices[a as int],
      QuestionType.vraiFaux => a == true ? 'Vrai' : 'Faux',
      QuestionType.quiADit => widget.trip.profileById(a as String)?.name ?? '?',
      QuestionType.estimation => formatNumber(a as double),
    };
  }

  bool _finishing = false;

  Future<void> _next() async {
    if (_phase != _Phase.revelation || _finishing) return;
    if (_turnIndex < _turns.length - 1) {
      setState(() {
        _turnIndex++;
        _answererIndex = 0;
        _answers.clear();
        _blurAtAnswer.clear();
        _phase = _Phase.passage;
      });
      _blur.reset();
      return;
    }

    // Fin de partie : on enregistre puis on affiche le podium.
    _finishing = true;
    final result = QuizResult(playedAt: DateTime.now(), scores: Map.of(_scores));
    try {
      await AppScope.of(context).repo.saveResult(widget.trip.code, result);
    } catch (_) {
      // Sans réseau, tant pis pour l'historique : on affiche quand même le podium.
    }
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => ResultsScreen(trip: widget.trip, result: result)),
    );
  }

  Future<void> _confirmQuit() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Arrêter la partie ?'),
        content: const Text('Les scores de cette partie ne seront pas gardés.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('CONTINUER')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('ARRÊTER')),
        ],
      ),
    );
    if (ok == true && mounted) Navigator.pop(context);
  }

  // ---------------------------------------------------------------------------
  // Affichage
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    if (_turns.isEmpty) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: Text('Aucune question jouable avec ces joueurs.')),
      );
    }

    return PopScope(
      canPop: false, // le bouton retour demande confirmation
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmQuit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('Question ${_turnIndex + 1} / ${_turns.length}',
              style: svScore(context, size: 18)),
          leading: IconButton(icon: const Icon(Icons.close), onPressed: _confirmQuit),
        ),
        body: SafeArea(
          // AnimatedSwitcher : petit fondu entre les phases.
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: switch (_phase) {
              _Phase.passage => _buildPassage(),
              _Phase.reponse => _buildAnswering(),
              _Phase.revelation => _buildReveal(),
            },
          ),
        ),
      ),
    );
  }

  // --- 1. Passer le téléphone ------------------------------------------------
  Widget _buildPassage() {
    final t = Theme.of(context).textTheme;
    final p = _currentPlayer;
    return Container(
      key: ValueKey('passage-$_turnIndex-$_answererIndex'),
      width: double.infinity,
      color: context.sv.tealDeep,
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Passe le téléphone à', style: t.bodyLarge?.copyWith(color: Colors.white)),
          const SizedBox(height: 24),
          ProfileAvatar(p, size: 120),
          const SizedBox(height: 16),
          Text(p.name, style: t.displaySmall?.copyWith(color: Colors.white)),
          const SizedBox(height: 48),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: SvColors.light.tealDeep,
              minimumSize: const Size(240, 56),
            ),
            onPressed: _showQuestion,
            child: const Text('C’EST MOI · VOIR LA QUESTION'),
          ),
        ],
      ),
    );
  }

  // --- 2. Répondre -------------------------------------------------------------
  Widget _buildAnswering() {
    final t = Theme.of(context).textTheme;
    final q = _turn.question;

    return ListView(
      key: ValueKey('reponse-$_turnIndex-$_answererIndex'),
      padding: const EdgeInsets.all(16),
      children: [
        Row(children: [
          ProfileAvatar(_currentPlayer, size: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text('${_currentPlayer.name} répond · ${q.type.label}', style: t.bodySmall),
          ),
        ]),
        const SizedBox(height: 16),
        if (q.photoUrl != null) ...[
          if (q.type == QuestionType.photoFloue)
            AnimatedBuilder(
              animation: _blur,
              builder: (_, _) => QuestionPhoto(
                url: q.photoUrl!,
                blur: _maxBlur * (1 - _blur.value),
                height: 260,
              ),
            )
          else
            QuestionPhoto(url: q.photoUrl!, height: 220),
          const SizedBox(height: 16),
        ],
        Text(
          q.type == QuestionType.quiADit ? '« ${q.prompt} »' : q.prompt,
          style: t.headlineMedium?.copyWith(fontSize: 26, height: 1.25),
        ),
        if (q.type == QuestionType.quiADit)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('Qui a dit ça ?', style: t.bodyLarge?.copyWith(color: context.sv.inkMuted)),
          ),
        const SizedBox(height: 24),
        ..._answerButtons(q),
      ],
    );
  }

  List<Widget> _answerButtons(Question q) {
    final t = Theme.of(context).textTheme;
    Widget bigButton(String label, VoidCallback onTap) => Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: SvCard(
            onTap: onTap,
            child: Text(label, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          ),
        );

    switch (q.type) {
      case QuestionType.qcm:
      case QuestionType.photoFloue:
        return [for (var i = 0; i < q.choices.length; i++) bigButton(q.choices[i], () => _answer(i))];
      case QuestionType.vraiFaux:
        return [
          Row(children: [
            Expanded(child: bigButton('Vrai', () => _answer(true))),
            const SizedBox(width: 12),
            Expanded(child: bigButton('Faux', () => _answer(false))),
          ]),
        ];
      case QuestionType.quiADit:
        return [
          Wrap(
            alignment: WrapAlignment.center,
            children: [
              for (final p in widget.trip.profiles)
                ProfileTile(profile: p, size: 60, onTap: () => _answer(p.id)),
            ],
          ),
        ];
      case QuestionType.estimation:
        return [
          Row(children: [
            Expanded(
              child: TextField(
                controller: _numberField,
                autofocus: true,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                style: svScore(context, size: 28),
                decoration: InputDecoration(suffixText: q.unit),
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: _parsedNumber == null ? null : () => _answer(_parsedNumber!),
              child: const Text('VALIDER'),
            ),
          ]),
        ];
    }
  }

  double? get _parsedNumber => double.tryParse(_numberField.text.trim().replaceAll(',', '.'));

  // --- 3. Révélation ------------------------------------------------------------
  Widget _buildReveal() {
    final t = Theme.of(context).textTheme;
    final q = _turn.question;
    final author = widget.trip.profileById(q.authorId);

    return Column(
      key: ValueKey('revelation-$_turnIndex'),
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (q.photoUrl != null) ...[
                QuestionPhoto(url: q.photoUrl!, height: 200),
                const SizedBox(height: 16),
              ],
              Text(q.type == QuestionType.quiADit ? '« ${q.prompt} »' : q.prompt,
                  style: t.titleLarge),
              const SizedBox(height: 12),
              // La bonne réponse, bien visible.
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.sv.tealSoft,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('BONNE RÉPONSE', style: t.labelLarge?.copyWith(color: context.sv.inkMuted)),
                  const SizedBox(height: 4),
                  Text(q.correctLabel(widget.trip),
                      style: t.headlineMedium?.copyWith(fontSize: 26)),
                ]),
              ),
              const SizedBox(height: 16),
              // Les réponses de chaque joueur.
              for (final p in _turn.answerers)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Row(children: [
                    ProfileAvatar(p, size: 36),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text(p.name, style: t.bodyLarge?.copyWith(fontWeight: FontWeight.w700)),
                        Text(_answerLabel(q, _answers[p.id]), style: t.bodySmall),
                      ]),
                    ),
                    // Un mot en plus de la couleur (charte : jamais la couleur seule).
                    Text(
                      (_turnPoints[p.id] ?? 0) > 0 ? '✓ +${_turnPoints[p.id]}' : '✗ raté',
                      style: svScore(context, size: 18).copyWith(
                        color: (_turnPoints[p.id] ?? 0) > 0 ? context.sv.teal : context.sv.danger,
                      ),
                    ),
                  ]),
                ),
              const SizedBox(height: 16),
              if (author != null)
                Wrap(crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text('Souvenir de ', style: t.bodySmall),
                  ProfileAvatar(author, size: 20),
                  Text(' ${author.name} · ${formatDay(q.createdAt)}', style: t.bodySmall),
                ]),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: _next,
              child: Text(_turnIndex < _turns.length - 1 ? 'QUESTION SUIVANTE' : 'VOIR LE PODIUM'),
            ),
          ),
        ),
      ],
    );
  }
}

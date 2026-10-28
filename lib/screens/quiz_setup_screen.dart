// =============================================================================
// quiz_setup_screen.dart — Préparer la partie
// -----------------------------------------------------------------------------
// Avant de jouer : qui est là ? Un joueur par question ou tout le monde ?
// Dans l'ordre des jours ou mélangé ?
// =============================================================================

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/sv_theme.dart';
import '../widgets/common.dart';
import 'quiz_play_screen.dart';

class QuizSetupScreen extends StatefulWidget {
  const QuizSetupScreen({super.key, required this.trip});
  final Trip trip;

  @override
  State<QuizSetupScreen> createState() => _QuizSetupScreenState();
}

class _QuizSetupScreenState extends State<QuizSetupScreen> {
  Future<List<Question>>? _questions;
  late final Set<String> _players = widget.trip.profiles.map((p) => p.id).toSet();
  QuizMode _mode = QuizMode.unParQuestion;
  bool _shuffle = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // On charge les questions une seule fois, à l'ouverture de l'écran.
    _questions ??= AppScope.of(context).repo.loadQuestions(widget.trip.code);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Préparer la partie')),
      body: FutureBuilder<List<Question>>(
        future: _questions,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Impossible de charger les souvenirs. Il faut du réseau.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _questions =
                      AppScope.of(context).repo.loadQuestions(widget.trip.code)),
                  child: const Text('RÉESSAYER'),
                ),
              ]),
            );
          }
          final questions = snap.data!;
          // Questions jouables avec les joueurs cochés.
          final playable =
              questions.where((q) => _players.any((id) => q.canAnswer(id))).length;

          return SafeArea(
            child: Column(children: [
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Text('Qui joue ?', style: t.titleLarge),
                    const SizedBox(height: 8),
                    Wrap(children: [
                      for (final p in widget.trip.profiles)
                        ProfileTile(
                          profile: p,
                          selected: _players.contains(p.id),
                          onTap: () => setState(() {
                            _players.contains(p.id) ? _players.remove(p.id) : _players.add(p.id);
                          }),
                        ),
                    ]),
                    const SizedBox(height: 24),
                    Text('Comment ?', style: t.titleLarge),
                    const SizedBox(height: 8),
                    for (final m in QuizMode.values)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: SvCard(
                          color: _mode == m ? context.sv.tealSoft : null,
                          onTap: () => setState(() => _mode = m),
                          child: Row(children: [
                            Icon(
                              _mode == m ? Icons.check_circle : Icons.radio_button_unchecked,
                              color: _mode == m ? context.sv.teal : context.sv.inkMuted,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                Text(m.label,
                                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                                Text(m.hint, style: t.bodySmall),
                              ]),
                            ),
                          ]),
                        ),
                      ),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: const Text('Mélanger les questions'),
                      subtitle: const Text('Sinon, dans l’ordre des jours.'),
                      value: _shuffle,
                      onChanged: (v) => setState(() => _shuffle = v),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: playable == 0 || _players.length < 2
                        ? null
                        : () => Navigator.pushReplacement(
                              context,
                              MaterialPageRoute(
                                builder: (_) => QuizPlayScreen(
                                  trip: widget.trip,
                                  questions: questions,
                                  players: widget.trip.profiles
                                      .where((p) => _players.contains(p.id))
                                      .toList(),
                                  mode: _mode,
                                  shuffle: _shuffle,
                                ),
                              ),
                            ),
                    child: Text(_players.length < 2
                        ? 'IL FAUT AU MOINS 2 JOUEURS'
                        : 'JOUER · $playable QUESTION${playable > 1 ? 'S' : ''}'),
                  ),
                ),
              ),
            ]),
          );
        },
      ),
    );
  }
}

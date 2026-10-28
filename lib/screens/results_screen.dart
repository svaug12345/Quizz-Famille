// =============================================================================
// results_screen.dart — Le podium de fin de partie
// =============================================================================

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/sv_theme.dart';
import '../widgets/common.dart';
import 'memories_screen.dart';

class ResultsScreen extends StatelessWidget {
  const ResultsScreen({super.key, required this.trip, required this.result});
  final Trip trip;
  final QuizResult result;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // Classement : du plus grand score au plus petit.
    final ranking = result.scores.entries
        .map((e) => (profile: trip.profileById(e.key), score: e.value))
        .where((r) => r.profile != null)
        .toList()
      ..sort((a, b) => b.score.compareTo(a.score));

    // Les ex æquo partagent la même place (1, 1, 3…).
    int placeOf(int i) {
      var place = i;
      while (place > 0 && ranking[place - 1].score == ranking[i].score) {
        place--;
      }
      return place + 1;
    }

    const medals = ['🥇', '🥈', '🥉'];

    return Scaffold(
      appBar: AppBar(title: const Text('Podium'), automaticallyImplyLeading: false),
      body: SafeArea(
        child: Column(children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (ranking.isNotEmpty) ...[
                  // Le ou les gagnants, en grand.
                  Center(child: ProfileAvatar(ranking.first.profile!, size: 110)),
                  const SizedBox(height: 12),
                  Center(
                    child: Text(
                      ranking.where((r) => r.score == ranking.first.score).length > 1
                          ? 'Égalité en tête !'
                          : '${ranking.first.profile!.name} gagne',
                      style: t.headlineMedium,
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
                for (var i = 0; i < ranking.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SvCard(
                      color: placeOf(i) == 1 ? context.sv.tealSoft : null,
                      child: Row(children: [
                        SizedBox(
                          width: 36,
                          child: Text(
                            placeOf(i) <= 3 ? medals[placeOf(i) - 1] : '${placeOf(i)}',
                            style: placeOf(i) <= 3
                                ? const TextStyle(fontSize: 24)
                                : svScore(context, size: 18),
                          ),
                        ),
                        ProfileAvatar(ranking[i].profile!, size: 36),
                        const SizedBox(width: 12),
                        Expanded(child: Text(ranking[i].profile!.name, style: t.titleMedium)),
                        Text('${ranking[i].score}', style: svScore(context)),
                        Text(' pt${ranking[i].score > 1 ? 's' : ''}', style: t.bodySmall),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pushReplacement(
                      context, MaterialPageRoute(builder: (_) => MemoriesScreen(trip: trip))),
                  child: const Text('CARNET'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('TERMINER'),
                ),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

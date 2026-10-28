// =============================================================================
// memories_screen.dart — Le carnet de souvenirs
// -----------------------------------------------------------------------------
// Une fois la boîte ouverte : toutes les questions, rangées jour par jour,
// avec leur photo, leur auteur et la bonne réponse. À relire des mois plus tard.
// =============================================================================

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/sv_theme.dart';
import '../widgets/common.dart';

class MemoriesScreen extends StatefulWidget {
  const MemoriesScreen({super.key, required this.trip});
  final Trip trip;

  @override
  State<MemoriesScreen> createState() => _MemoriesScreenState();
}

class _MemoriesScreenState extends State<MemoriesScreen> {
  Future<List<Question>>? _questions;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _questions ??= AppScope.of(context).repo.loadQuestions(widget.trip.code);
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text('${widget.trip.emoji}  Carnet')),
      body: FutureBuilder<List<Question>>(
        future: _questions,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snap.hasError) {
            return Center(
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                const Text('Impossible de charger le carnet. Il faut du réseau.'),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => setState(() => _questions =
                      AppScope.of(context).repo.loadQuestions(widget.trip.code)),
                  child: const Text('RÉESSAYER'),
                ),
              ]),
            );
          }
          final questions = [...snap.data!]
            ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

          // On regroupe par jour : clé = date sans l'heure.
          final byDay = <DateTime, List<Question>>{};
          for (final q in questions) {
            final day = DateTime(q.createdAt.year, q.createdAt.month, q.createdAt.day);
            byDay.putIfAbsent(day, () => []).add(q);
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              for (final entry in byDay.entries) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  // Majuscule au jour : « Samedi 24 octobre ».
                  child: Text(
                    formatDay(entry.key).replaceRange(0, 1, formatDay(entry.key)[0].toUpperCase()),
                    style: t.titleLarge,
                  ),
                ),
                for (final q in entry.value)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _MemoryCard(trip: widget.trip, question: q),
                  ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  const _MemoryCard({required this.trip, required this.question});
  final Trip trip;
  final Question question;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final q = question;
    final author = trip.profileById(q.authorId);
    final time = '${q.createdAt.hour.toString().padLeft(2, '0')}h'
        '${q.createdAt.minute.toString().padLeft(2, '0')}';

    return SvCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            if (author != null) ProfileAvatar(author, size: 28),
            const SizedBox(width: 8),
            Expanded(
              child: Text('${author?.name ?? '?'} · $time', style: t.bodySmall),
            ),
            Text(q.type.emoji),
          ]),
          const SizedBox(height: 12),
          if (q.photoUrl != null) ...[
            QuestionPhoto(url: q.photoUrl!, height: 180),
            const SizedBox(height: 12),
          ],
          Text(q.type == QuestionType.quiADit ? '« ${q.prompt} »' : q.prompt,
              style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text.rich(TextSpan(children: [
            TextSpan(text: 'Réponse : ', style: t.bodyMedium?.copyWith(color: context.sv.inkMuted)),
            TextSpan(
              text: q.correctLabel(trip),
              style: t.bodyMedium?.copyWith(fontWeight: FontWeight.w800, color: context.sv.teal),
            ),
          ])),
        ],
      ),
    );
  }
}

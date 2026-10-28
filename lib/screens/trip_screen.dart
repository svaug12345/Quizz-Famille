// =============================================================================
// trip_screen.dart — L'écran d'un voyage
// -----------------------------------------------------------------------------
// Deux visages selon l'étape :
//   • COLLECTE : la boîte est scellée. On voit combien de souvenirs chacun a
//     déposés (jamais leur contenu), et on choisit qui ajoute une question.
//   • QUIZ / TERMINÉ : la boîte est ouverte. On joue, on revoit le carnet.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/models.dart';
import '../theme/sv_theme.dart';
import '../widgets/common.dart';
import 'add_question_screen.dart';
import 'memories_screen.dart';
import 'quiz_setup_screen.dart';

class TripScreen extends StatefulWidget {
  const TripScreen({super.key, required this.code});
  final String code;

  @override
  State<TripScreen> createState() => _TripScreenState();
}

class _TripScreenState extends State<TripScreen> {
  Stream<Trip?>? _trip;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _trip ??= AppScope.of(context).repo.watchTrip(widget.code);
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Trip?>(
      stream: _trip,
      builder: (context, snap) {
        final trip = snap.data;
        if (trip == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: snap.connectionState == ConnectionState.waiting
                  ? const CircularProgressIndicator()
                  : const Text('Voyage introuvable.'),
            ),
          );
        }
        return Scaffold(
          appBar: AppBar(
            title: Text('${trip.emoji}  ${trip.title}'),
            actions: [
              IconButton(
                tooltip: 'Inviter un téléphone',
                icon: const Icon(Icons.qr_code_2),
                onPressed: () => _showInvite(context, trip),
              ),
            ],
          ),
          body: SafeArea(
            child: trip.status == TripStatus.collecte
                ? _CollectView(
                    trip: trip,
                    // Les profils « de ce téléphone » ne passent pas par le flux
                    // du voyage : quand ils changent, on redessine à la main.
                    onLocalChanged: () => setState(() {}),
                  )
                : _PlayView(trip: trip),
          ),
        );
      },
    );
  }
}

// -----------------------------------------------------------------------------
// Invitation : grand code + QR code (lisible avec ton appli Lecteur QR,
// ou par la future fonction « scanner » de l'appli).
// -----------------------------------------------------------------------------
void _showInvite(BuildContext context, Trip trip) {
  final t = Theme.of(context).textTheme;
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Inviter un téléphone', style: t.titleLarge),
            const SizedBox(height: 8),
            Text(
              'Sur l’autre téléphone : Quiz’Vacances → REJOINDRE → ce code.',
              style: t.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            // Le QR code se dessine sur fond blanc pour rester lisible en thème sombre.
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: trip.code,
                size: 180,
                eyeStyle: const QrEyeStyle(
                    eyeShape: QrEyeShape.square, color: Color(0xFF102A2E)),
                dataModuleStyle: const QrDataModuleStyle(
                    dataModuleShape: QrDataModuleShape.square, color: Color(0xFF102A2E)),
              ),
            ),
            const SizedBox(height: 16),
            // Le code en gros, chiffres à chasse fixe (style « score » de la charte).
            InkWell(
              borderRadius: BorderRadius.circular(6),
              onTap: () {
                Clipboard.setData(ClipboardData(text: trip.code));
                Navigator.pop(ctx); // on ferme la feuille pour voir le message
                ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('Code copié.')));
              },
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(trip.code, style: svScore(ctx, size: 36).copyWith(letterSpacing: 6)),
                  const SizedBox(width: 8),
                  Icon(Icons.copy, size: 20, color: ctx.sv.inkMuted),
                ]),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

// =============================================================================
// ÉTAPE 1 : COLLECTE
// =============================================================================
class _CollectView extends StatelessWidget {
  const _CollectView({required this.trip, required this.onLocalChanged});
  final Trip trip;
  final VoidCallback onLocalChanged;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;

    // Les profils « portés » par ce téléphone (et qui existent toujours).
    final localIds = scope.device.localProfiles(trip.code);
    final local = trip.profiles.where((p) => localIds.contains(p.id)).toList();

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // --- La boîte scellée ------------------------------------------
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.sv.tealDeep,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    const Text('🔒', style: TextStyle(fontSize: 40)),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${trip.questionCount}',
                            style: svScore(context, size: 40).copyWith(color: Colors.white),
                          ),
                          Text(
                            trip.questionCount > 1
                                ? 'souvenirs scellés dans la boîte'
                                : 'souvenir scellé dans la boîte',
                            style: t.bodyMedium?.copyWith(color: Colors.white),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),

              // Qui a déposé combien (le contenu reste secret).
              Wrap(
                children: [
                  for (final p in trip.profiles)
                    ProfileTile(
                      profile: p,
                      size: 40,
                      badge: '${trip.countByAuthor[p.id] ?? 0}',
                    ),
                ],
              ),
              const SizedBox(height: 24),

              // --- Qui ajoute un souvenir ? ----------------------------------
              Text('Ajouter un souvenir', style: t.titleLarge),
              const SizedBox(height: 4),
              Text(
                local.isEmpty
                    ? 'Commence par dire qui utilise ce téléphone.'
                    : 'Touche ton profil. Appui long pour le retirer de ce téléphone.',
                style: t.bodySmall,
              ),
              const SizedBox(height: 12),
              Wrap(
                children: [
                  for (final p in local)
                    ProfileTile(
                      profile: p,
                      onTap: () => _openAddQuestion(context, p),
                      onLongPress: () => _removeLocal(context, p),
                    ),
                  _AddTile(onTap: () => _addLocalProfile(context)),
                ],
              ),
              const SizedBox(height: 24),
              _TipsCard(),
            ],
          ),
        ),

        // --- Ouvrir la boîte ---------------------------------------------------
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.lock_open),
              label: const Text('OUVRIR LA BOÎTE ET LANCER LE QUIZ'),
              onPressed: trip.questionCount == 0 ? null : () => _confirmStart(context),
            ),
          ),
        ),
      ],
    );
  }

  /// Ouvre l'écran d'ajout, après vérification du code du profil.
  Future<void> _openAddQuestion(BuildContext context, Profile author) async {
    if (!await showPinCheck(context, author)) return;
    if (!context.mounted) return;
    final repo = AppScope.of(context).repo;
    // L'écran d'ajout renvoie la question déposée (ou null si abandon).
    final added = await Navigator.push<Question>(
      context,
      MaterialPageRoute(builder: (_) => AddQuestionScreen(trip: trip, author: author)),
    );
    if (added == null || !context.mounted) return;
    // Confirmation + petite fenêtre pour annuler (faute de frappe, mauvaise réponse…).
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 8),
        // Depuis Flutter 3.29, un SnackBar qui a un bouton (ici ANNULER) reste
        // affiché pour toujours par défaut : la durée ci-dessus est ignorée.
        // Il cachait alors le bouton « OUVRIR LA BOÎTE ». persist: false
        // rétablit la disparition automatique au bout des 8 secondes.
        persist: false,
        content: const Text('Souvenir scellé dans la boîte 🔒'),
        action: SnackBarAction(
          label: 'ANNULER',
          onPressed: () => repo.undoQuestion(trip.code, added),
        ),
      ),
    );
  }

  /// « Qui es-tu ? » : choisir un profil existant ou en créer un.
  Future<void> _addLocalProfile(BuildContext context) async {
    final scope = AppScope.of(context);
    final localIds = scope.device.localProfiles(trip.code);
    final others = trip.profiles.where((p) => !localIds.contains(p.id)).toList();

    final chosen = await showModalBottomSheet<Object>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Qui es-tu ?', style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 12),
              Wrap(children: [
                for (final p in others)
                  ProfileTile(profile: p, onTap: () => Navigator.pop(ctx, p)),
                // 'new' = créer un nouveau profil
                _AddTile(label: 'Nouveau', onTap: () => Navigator.pop(ctx, 'new')),
              ]),
            ],
          ),
        ),
      ),
    );
    if (!context.mounted || chosen == null) return;

    if (chosen is Profile) {
      // Profil existant : on vérifie son code avant de le mettre sur ce téléphone.
      if (!await showPinCheck(context, chosen)) return;
      await scope.device.addLocalProfile(trip.code, chosen.id);
    } else {
      final p = await showNewProfileSheet(context, colorSeed: trip.profiles.length);
      if (p == null) return;
      await scope.repo.addProfile(trip.code, p);
      await scope.device.addLocalProfile(trip.code, p.id);
    }
    if (context.mounted) onLocalChanged();
  }

  Future<void> _removeLocal(BuildContext context, Profile p) async {
    final device = AppScope.of(context).device;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer ${p.name} de ce téléphone ?'),
        content: const Text('Le profil reste dans le voyage, ses souvenirs aussi.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('RETIRER')),
        ],
      ),
    );
    if (ok != true) return;
    await device.removeLocalProfile(trip.code, p.id);
    if (context.mounted) onLocalChanged();
  }

  Future<void> _confirmStart(BuildContext context) async {
    final repo = AppScope.of(context).repo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ouvrir la boîte ?'),
        content: Text(
          '${trip.questionCount} souvenir${trip.questionCount > 1 ? 's vont' : ' va'} devenir un quiz. '
          'Ensuite, plus personne ne pourra en ajouter. C’est définitif.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('PAS ENCORE')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('OUVRIR')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await repo.startQuiz(trip.code);
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Il faut du réseau pour ouvrir la boîte. Réessaie quand ça capte.')));
    }
  }
}

/// Tuile « + » au même gabarit que ProfileTile.
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap, this.label = 'C’est moi'});
  final VoidCallback onTap;
  final String label;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: 76,
          child: Column(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.sv.line, width: 2),
              ),
              child: Icon(Icons.add, color: context.sv.teal),
            ),
            const SizedBox(height: 6),
            Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ]),
        ),
      ),
    );
  }
}

class _TipsCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return SvCard(
      color: context.sv.tealSoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('💡 Idées de souvenirs', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text(
            '• Combien de crêpes a mangé Tom ce midi ?\n'
            '• Photo mystère : un détail du paysage du jour.\n'
            '• Qui a dit « on est bientôt arrivés ? » ?\n'
            '• Vrai ou faux : on a vu un phoque.',
            style: t.bodyMedium,
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// ÉTAPE 2 : LA BOÎTE EST OUVERTE
// =============================================================================
class _PlayView extends StatelessWidget {
  const _PlayView({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final last = trip.results.isEmpty ? null : trip.results.last;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: context.sv.tealDeep,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('🎲 La boîte est ouverte',
                  style: t.titleLarge?.copyWith(color: Colors.white)),
              const SizedBox(height: 4),
              Text('${trip.questionCount} souvenirs à redécouvrir en famille.',
                  style: t.bodyMedium?.copyWith(color: Colors.white)),
              const SizedBox(height: 16),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: SvColors.light.tealDeep,
                ),
                onPressed: () => Navigator.push(context,
                    MaterialPageRoute(builder: (_) => QuizSetupScreen(trip: trip))),
                child: Text(trip.results.isEmpty ? 'JOUER' : 'REJOUER'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SvCard(
          onTap: () => Navigator.push(
              context, MaterialPageRoute(builder: (_) => MemoriesScreen(trip: trip))),
          child: Row(children: [
            const Text('📖', style: TextStyle(fontSize: 32)),
            const SizedBox(width: 16),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Carnet de souvenirs',
                    style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                Text('Toutes les questions, jour par jour, avec les réponses.',
                    style: t.bodySmall),
              ]),
            ),
            Icon(Icons.chevron_right, color: context.sv.inkMuted),
          ]),
        ),
        if (last != null) ...[
          const SizedBox(height: 24),
          Text('Dernière partie · ${formatShortDate(last.playedAt)}', style: t.titleLarge),
          const SizedBox(height: 8),
          for (final e in (last.scores.entries.toList()
            ..sort((a, b) => b.value.compareTo(a.value))))
            if (trip.profileById(e.key) case final p?)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  ProfileAvatar(p, size: 32),
                  const SizedBox(width: 12),
                  Expanded(child: Text(p.name, style: t.bodyLarge)),
                  Text('${e.value}', style: svScore(context, size: 20)),
                ]),
              ),
        ],
      ],
    );
  }
}

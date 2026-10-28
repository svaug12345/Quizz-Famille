// =============================================================================
// home_screen.dart — Accueil : la liste des voyages
// -----------------------------------------------------------------------------
// Affiche les voyages connus de ce téléphone, du plus récent au plus ancien,
// et deux boutons : créer un voyage / rejoindre celui d'un autre téléphone.
// =============================================================================

import 'package:flutter/material.dart';

import '../main.dart' show kAppVersion;
import '../models/models.dart';
import '../theme/sv_theme.dart';
import '../widgets/common.dart';
import 'create_trip_screen.dart';
import 'join_trip_screen.dart';
import 'trip_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // On crée le flux UNE seule fois et on le garde : si on l'appelait dans
  // build(), chaque redessin relancerait un nouvel abonnement.
  Stream<List<Trip>>? _trips;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _trips ??= AppScope.of(context).repo.watchMyTrips();
  }

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Quiz'Vacances"),
        actions: [
          IconButton(
            tooltip: 'À propos',
            icon: const Icon(Icons.info_outline),
            onPressed: () => _showAbout(context, scope.repo.isShared),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Petit bandeau tant que Firebase n'est pas branché.
            if (!scope.repo.isShared)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: context.sv.tealSoft,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  'Mode démo : les voyages restent sur ce téléphone.',
                  style: t.bodySmall?.copyWith(color: context.sv.ink),
                ),
              ),

            // La liste, mise à jour en direct grâce au StreamBuilder :
            // à chaque nouvelle valeur du flux, cette partie se redessine.
            Expanded(
              child: StreamBuilder<List<Trip>>(
                stream: _trips,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return const Center(
                        child: Text('Impossible de charger les voyages (réseau ?).'));
                  }
                  if (!snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final trips = snap.data!;
                  if (trips.isEmpty) return const _EmptyState();
                  return ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: trips.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 12),
                    itemBuilder: (context, i) => _TripCard(trip: trips[i]),
                  );
                },
              ),
            ),

            // Les deux actions principales, toujours en bas (zone du pouce).
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const JoinTripScreen())),
                      child: const Text('REJOINDRE'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => Navigator.push(context,
                          MaterialPageRoute(builder: (_) => const CreateTripScreen())),
                      child: const Text('NOUVEAU VOYAGE'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAbout(BuildContext context, bool shared) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Charte SV : le geste en petit, couleur ink-muted, sans texte collé.
            SvMark(size: 40, color: context.sv.inkMuted),
            const SizedBox(height: 16),
            Text("Quiz'Vacances", style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 4),
            Text('v$kAppVersion', style: svScore(ctx, size: 14)),
            const SizedBox(height: 12),
            Text(
              shared
                  ? 'Les souvenirs sont partagés entre les téléphones du voyage.'
                  : 'Mode démo : tout reste sur ce téléphone.',
              textAlign: TextAlign.center,
              style: Theme.of(ctx).textTheme.bodySmall,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('FERMER')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧳', style: TextStyle(fontSize: 64)),
            const SizedBox(height: 16),
            Text('Aucun voyage pour l’instant', style: t.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Crée une boîte à souvenirs avant de partir. Chacun y glisse ses '
              'questions au fil des jours, et on joue tous ensemble au retour.',
              style: t.bodyMedium?.copyWith(color: context.sv.inkMuted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final Trip trip;

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    // Le petit texte d'état sous le titre.
    final status = switch (trip.status) {
      TripStatus.collecte =>
        '🔒 ${trip.questionCount} souvenir${trip.questionCount > 1 ? 's' : ''} dans la boîte',
      TripStatus.quiz => '🎲 Quiz prêt à jouer',
      TripStatus.termine => trip.results.isEmpty
          ? '🏆 Quiz joué'
          : '🏆 Joué ${trip.results.length} fois · ${formatShortDate(trip.results.last.playedAt)}',
    };

    return SvCard(
      onTap: () => Navigator.push(
          context, MaterialPageRoute(builder: (_) => TripScreen(code: trip.code))),
      // Appui long : retirer le voyage de ce téléphone.
      onLongPress: () => _confirmForget(context),
      child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: context.sv.tealSoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(trip.emoji, style: const TextStyle(fontSize: 28)),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(trip.title, style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text(status, style: t.bodySmall),
                ],
              ),
            ),
            // Mini-pile d'avatars des membres.
            SizedBox(
              width: 28.0 + 14 * (trip.profiles.length.clamp(1, 4) - 1),
              height: 28,
              child: Stack(
                children: [
                  for (var i = 0; i < trip.profiles.length && i < 4; i++)
                    Positioned(left: i * 14.0, child: ProfileAvatar(trip.profiles[i], size: 28)),
                ],
              ),
            ),
          ],
        ),
    );
  }

  Future<void> _confirmForget(BuildContext context) async {
    final repo = AppScope.of(context).repo;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Retirer « ${trip.title} » ?'),
        content: const Text(
            'Le voyage disparaît de ce téléphone. Les autres téléphones le gardent.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('RETIRER')),
        ],
      ),
    );
    if (ok == true) await repo.forgetTrip(trip.code);
  }
}

// =============================================================================
// create_trip_screen.dart — Créer un voyage (une nouvelle boîte à souvenirs)
// -----------------------------------------------------------------------------
// On choisit un titre, un emoji, et on ajoute les membres de la famille.
// Les profils créés ici sont automatiquement « portés » par ce téléphone.
// =============================================================================

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../theme/sv_theme.dart';
import '../widgets/common.dart';
import 'trip_screen.dart';

const kTripEmojis = ['🏖️', '🏔️', '⛷️', '🏕️', '🌲', '🏰', '🚗', '✈️', '🚤', '🎡', '🐑', '🧳'];

class CreateTripScreen extends StatefulWidget {
  const CreateTripScreen({super.key});

  @override
  State<CreateTripScreen> createState() => _CreateTripScreenState();
}

class _CreateTripScreenState extends State<CreateTripScreen> {
  final _title = TextEditingController();
  String _emoji = kTripEmojis.first;
  final List<Profile> _profiles = [];
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _addProfile() async {
    final p = await showNewProfileSheet(context, colorSeed: _profiles.length);
    if (p != null && mounted) setState(() => _profiles.add(p));
  }

  Future<void> _create() async {
    final scope = AppScope.of(context);
    setState(() => _saving = true);
    try {
      final trip = await scope.repo.createTrip(
        title: _title.text.trim(),
        emoji: _emoji,
        profiles: _profiles,
      );
      // Tous les profils créés ici sont sur ce téléphone.
      for (final p in _profiles) {
        await scope.device.addLocalProfile(trip.code, p.id);
      }
      if (!mounted) return;
      // pushReplacement : on remplace cet écran (pas de retour au formulaire).
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => TripScreen(code: trip.code)));
    } catch (e) {
      if (!mounted) return; // l'écran a pu être fermé entre-temps
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Création impossible (réseau ?) : $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final canCreate = _title.text.trim().isNotEmpty && _profiles.isNotEmpty && !_saving;

    return Scaffold(
      appBar: AppBar(title: const Text('Nouveau voyage')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            TextField(
              controller: _title,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Nom du voyage',
                hintText: 'Week-end à Étretat',
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 24),
            Text('Emoji', style: t.titleLarge),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final e in kTripEmojis)
                  InkWell(
                    onTap: () => setState(() => _emoji = e),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      width: 52,
                      height: 52,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: e == _emoji ? context.sv.tealSoft : context.sv.surfaceRaised,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                            color: e == _emoji ? context.sv.teal : context.sv.line,
                            width: e == _emoji ? 2 : 1),
                      ),
                      child: Text(e, style: const TextStyle(fontSize: 26)),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Qui part ?', style: t.titleLarge),
            const SizedBox(height: 4),
            Text(
              'Ajoute les membres de la famille. Tu pourras en ajouter d’autres en route.',
              style: t.bodySmall,
            ),
            const SizedBox(height: 12),
            Wrap(
              children: [
                for (final p in _profiles)
                  ProfileTile(
                    profile: p,
                    badge: p.hasPin ? '🔑 code' : null,
                    // Appui = retirer de la liste (avant création seulement).
                    onTap: () => setState(() => _profiles.remove(p)),
                  ),
                // Bouton « + » au même format que les profils.
                InkWell(
                  onTap: _addProfile,
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
                        Text('Ajouter', style: t.bodyMedium),
                      ]),
                    ),
                  ),
                ),
              ],
            ),
            if (_profiles.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('Touche un profil pour le retirer.', style: t.bodySmall),
              ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: canCreate ? _create : null,
            child: Text(_saving ? 'CRÉATION…' : 'CRÉER LA BOÎTE'),
          ),
        ),
      ),
    );
  }
}

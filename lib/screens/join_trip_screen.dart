// =============================================================================
// join_trip_screen.dart — Rejoindre le voyage créé sur un autre téléphone
// -----------------------------------------------------------------------------
// On tape le code à 6 caractères affiché sur le téléphone qui a créé le voyage.
// =============================================================================

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/common.dart';
import 'trip_screen.dart';

class JoinTripScreen extends StatefulWidget {
  const JoinTripScreen({super.key});

  @override
  State<JoinTripScreen> createState() => _JoinTripScreenState();
}

class _JoinTripScreenState extends State<JoinTripScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _join() async {
    final repo = AppScope.of(context).repo;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final trip = await repo.joinTrip(_code.text.trim().toUpperCase());
      if (!mounted) return;
      if (trip == null) {
        setState(() {
          _busy = false;
          _error = repo.isShared
              ? 'Aucun voyage avec ce code.'
              : 'Aucun voyage avec ce code. En mode démo, on ne peut rejoindre '
                  'que les voyages créés sur ce téléphone.';
        });
        return;
      }
      Navigator.pushReplacement(
          context, MaterialPageRoute(builder: (_) => TripScreen(code: trip.code)));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = 'Connexion impossible. Vérifie le réseau et réessaie.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Rejoindre un voyage')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Demande le code affiché sur le téléphone qui a créé le voyage.',
                style: t.bodyLarge,
              ),
              const SizedBox(height: 24),
              TextField(
                controller: _code,
                autofocus: true,
                textAlign: TextAlign.center,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                // On n'accepte que lettres et chiffres, et on met en majuscules.
                inputFormatters: [
                  FilteringTextInputFormatter.allow(RegExp('[a-zA-Z0-9]')),
                  _UpperCase(),
                ],
                style: t.headlineMedium?.copyWith(letterSpacing: 8),
                decoration: InputDecoration(hintText: 'ABC234', errorText: _error),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => !_busy && _code.text.length == 6 ? _join() : null,
              ),
              const Spacer(),
              FilledButton(
                onPressed: _code.text.length == 6 && !_busy ? _join : null,
                child: Text(_busy ? 'RECHERCHE…' : 'REJOINDRE'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Met automatiquement en majuscules ce qui est tapé.
class _UpperCase extends TextInputFormatter {
  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) =>
      newValue.copyWith(text: newValue.text.toUpperCase());
}

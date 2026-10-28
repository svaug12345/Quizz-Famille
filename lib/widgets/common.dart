// =============================================================================
// common.dart — Petits widgets réutilisés dans plusieurs écrans
// -----------------------------------------------------------------------------
//   AppScope         : rend le dépôt de données accessible partout
//   SvMark           : le logo SV (le geste), dans une couleur au choix
//   ProfileAvatar    : la pastille ronde d'un profil (emoji + couleur)
//   QuestionPhoto    : affiche une photo (URL Firebase ou data: en mode démo)
//   AnswerersPicker  : « Qui peut répondre ? » (tout le monde / certains)
//   showPinCheck     : demande le code secret d'un profil
//   showNewProfileSheet : formulaire d'ajout d'un profil
// =============================================================================

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../theme/sv_theme.dart';
import 'sv_mark_path.dart';

// -----------------------------------------------------------------------------
// AppScope : un InheritedWidget placé tout en haut de l'appli.
// N'importe quel écran peut écrire AppScope.of(context).repo pour accéder
// aux données, sans devoir les passer de constructeur en constructeur.
// -----------------------------------------------------------------------------
class AppScope extends InheritedWidget {
  const AppScope({
    super.key,
    required this.repo,
    required this.device,
    required super.child,
  });

  final QuizRepository repo;
  final DeviceState device;

  static AppScope of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<AppScope>()!;

  @override
  bool updateShouldNotify(AppScope old) => repo != old.repo;
}

// -----------------------------------------------------------------------------
// SvMark : le geste SV. [reveal] (0 → 1) permet de le « dessiner » de gauche
// à droite pour l'écran de lancement, comme le recommande la charte.
// -----------------------------------------------------------------------------
class SvMark extends StatelessWidget {
  const SvMark({super.key, this.size = 32, this.color, this.reveal = 1});

  final double size;
  final Color? color;
  final double reveal;

  static const _svg =
      '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64">'
      '<path fill="#000000" d="$kSvMarkPath"/></svg>';

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      // Align + widthFactor : on n'affiche qu'une fraction de la largeur.
      child: Align(
        alignment: Alignment.centerLeft,
        widthFactor: reveal.clamp(0.0, 1.0),
        child: SvgPicture.string(
          _svg,
          width: size,
          height: size,
          // srcIn : on remplace la couleur noire du tracé par la nôtre.
          colorFilter: ColorFilter.mode(color ?? context.sv.ink, BlendMode.srcIn),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// ProfileAvatar
// -----------------------------------------------------------------------------
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar(this.profile, {super.key, this.size = 44, this.selected = false});

  final Profile profile;
  final double size;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: SvColors.profileColor(profile.color),
        shape: BoxShape.circle,
        // Anneau turquoise autour du profil sélectionné.
        border: selected ? Border.all(color: context.sv.accent, width: 3) : null,
      ),
      child: Text(profile.emoji, style: TextStyle(fontSize: size * 0.5)),
    );
  }
}

/// Avatar + prénom en dessous, cliquable. Utilisé dans les grilles de profils.
class ProfileTile extends StatelessWidget {
  const ProfileTile({
    super.key,
    required this.profile,
    this.selected = false,
    this.onTap,
    this.onLongPress,
    this.badge,
    this.size = 56,
  });

  final Profile profile;
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final String? badge; // petit texte sous le prénom (ex. « 3 souvenirs »)
  final double size;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          width: size + 20,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ProfileAvatar(profile, size: size, selected: selected),
              const SizedBox(height: 6),
              Text(
                profile.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: selected ? FontWeight.w800 : FontWeight.w600),
              ),
              if (badge != null)
                Text(badge!, style: Theme.of(context).textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// QuestionPhoto : affiche une photo, éventuellement floutée.
// [blur] = 0 → nette ; 20 → très floue.
// -----------------------------------------------------------------------------
class QuestionPhoto extends StatelessWidget {
  const QuestionPhoto({super.key, required this.url, this.blur = 0, this.height = 220});

  final String url;
  final double blur;
  final double height;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (url.startsWith('data:')) {
      // Mode démo : la photo est rangée en texte base64 après la virgule.
      final bytes = base64Decode(url.substring(url.indexOf(',') + 1));
      image = Image.memory(bytes, fit: BoxFit.cover, gaplessPlayback: true);
    } else if (url.startsWith('http')) {
      image = Image.network(url, fit: BoxFit.cover, gaplessPlayback: true);
    } else {
      // Photo pas encore disponible (envoi en attente).
      image = Container(
        color: context.sv.tealSoft,
        alignment: Alignment.center,
        child: const Text('📷', style: TextStyle(fontSize: 40)),
      );
    }

    if (blur > 0) {
      // ImageFiltered applique un flou gaussien à tout ce qu'il contient.
      image = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: image,
      );
    }

    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(height: height, width: double.infinity, child: image),
    );
  }
}

// -----------------------------------------------------------------------------
// AnswerersPicker : « Qui peut répondre ? »
// selected vide = tout le monde (sauf l'auteur, toujours exclu).
// -----------------------------------------------------------------------------
class AnswerersPicker extends StatelessWidget {
  const AnswerersPicker({
    super.key,
    required this.trip,
    required this.authorId,
    required this.selected,
    required this.onChanged,
    required this.onAddProfile,
  });

  final Trip trip;
  final String authorId;
  final List<String> selected;
  final ValueChanged<List<String>> onChanged;
  final VoidCallback onAddProfile;

  @override
  Widget build(BuildContext context) {
    final others = trip.profiles.where((p) => p.id != authorId).toList();
    final everyone = selected.isEmpty;

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ChoiceChip(
          label: const Text('Tout le monde'),
          selected: everyone,
          onSelected: (_) => onChanged(const []),
        ),
        for (final p in others)
          FilterChip(
            avatar: Text(p.emoji),
            label: Text(p.name),
            // Quand « tout le monde » est actif, aucune puce individuelle
            // n'est cochée : un clic passe en mode « seulement certains ».
            selected: !everyone && selected.contains(p.id),
            onSelected: (on) {
              final next = [...selected];
              if (on) {
                next.add(p.id);
              } else {
                next.remove(p.id);
              }
              // Plus personne de coché → on revient à « tout le monde ».
              onChanged(next);
            },
          ),
        ActionChip(
          avatar: const Icon(Icons.add, size: 18),
          label: const Text('Ajouter'),
          onPressed: onAddProfile,
        ),
      ],
    );
  }
}

// -----------------------------------------------------------------------------
// Code secret d'un profil
// -----------------------------------------------------------------------------

/// Demande le code d'un profil. Renvoie true si c'est bon (ou s'il n'y a pas de code).
Future<bool> showPinCheck(BuildContext context, Profile profile) async {
  if (!profile.hasPin) return true;
  final controller = TextEditingController();
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Code de ${profile.name}'),
      content: TextField(
        controller: controller,
        autofocus: true,
        obscureText: true,
        keyboardType: TextInputType.number,
        maxLength: 4,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: const InputDecoration(hintText: '4 chiffres'),
        onSubmitted: (v) => Navigator.pop(ctx, v == profile.pin),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('ANNULER')),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, controller.text == profile.pin),
          child: const Text('OK'),
        ),
      ],
    ),
  );
  if (ok != true && context.mounted) {
    ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Code incorrect.')));
  }
  return ok == true;
}

// -----------------------------------------------------------------------------
// Formulaire « Nouveau profil » (feuille qui monte du bas de l'écran)
// -----------------------------------------------------------------------------
const kProfileEmojis = [
  '🦊', '🐻', '🐼', '🐸', '🦁', '🐯', '🐨', '🐙',
  '🦄', '🐢', '🦉', '🐬', '🐝', '🦖', '👵', '👴',
];

Future<Profile?> showNewProfileSheet(BuildContext context, {int colorSeed = 0}) {
  return showModalBottomSheet<Profile>(
    context: context,
    isScrollControlled: true, // la feuille remonte au-dessus du clavier
    showDragHandle: true,
    builder: (ctx) => _NewProfileForm(colorSeed: colorSeed),
  );
}

class _NewProfileForm extends StatefulWidget {
  const _NewProfileForm({required this.colorSeed});
  final int colorSeed;

  @override
  State<_NewProfileForm> createState() => _NewProfileFormState();
}

class _NewProfileFormState extends State<_NewProfileForm> {
  final _name = TextEditingController();
  final _pin = TextEditingController();
  late String _emoji = kProfileEmojis[widget.colorSeed % kProfileEmojis.length];
  late int _color = widget.colorSeed % kProfileColorCount;

  @override
  void dispose() {
    _name.dispose();
    _pin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
    final preview = Profile(id: '', name: _name.text, emoji: _emoji, color: _color);

    return Padding(
      // viewInsets.bottom = hauteur du clavier : on pousse le contenu au-dessus.
      padding: EdgeInsets.fromLTRB(16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(children: [
              ProfileAvatar(preview, size: 52),
              const SizedBox(width: 12),
              Text('Nouveau profil', style: t.titleLarge),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              autofocus: true,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Prénom'),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            Text('Avatar', style: t.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 4, runSpacing: 4, children: [
              for (final e in kProfileEmojis)
                InkWell(
                  onTap: () => setState(() => _emoji = e),
                  borderRadius: BorderRadius.circular(8),
                  child: Container(
                    width: 40,
                    height: 40,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: e == _emoji ? context.sv.tealSoft : null,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(e, style: const TextStyle(fontSize: 22)),
                  ),
                ),
            ]),
            const SizedBox(height: 12),
            Text('Couleur', style: t.bodySmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, children: [
              for (var i = 0; i < kProfileColorCount; i++)
                GestureDetector(
                  onTap: () => setState(() => _color = i),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: SvColors.profileColor(i),
                      shape: BoxShape.circle,
                      border: i == _color
                          ? Border.all(color: context.sv.ink, width: 3)
                          : null,
                    ),
                  ),
                ),
            ]),
            const SizedBox(height: 16),
            TextField(
              controller: _pin,
              keyboardType: TextInputType.number,
              obscureText: true,
              maxLength: 4,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: const InputDecoration(
                labelText: 'Code secret (facultatif)',
                helperText: 'Pour que personne ne pose de question à ta place.',
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _name.text.trim().isEmpty
                    ? null // bouton grisé tant qu'il n'y a pas de prénom
                    : () => Navigator.pop(
                          context,
                          Profile(
                            id: newId(),
                            name: _name.text.trim(),
                            emoji: _emoji,
                            color: _color,
                            pin: _pin.text.length == 4 ? _pin.text : null,
                          ),
                        ),
                child: const Text('AJOUTER'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Une carte simple aux couleurs SV, avec marge intérieure space-4.
class SvCard extends StatelessWidget {
  const SvCard({super.key, required this.child, this.onTap, this.onLongPress, this.color});

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: color,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(padding: const EdgeInsets.all(16), child: child),
      ),
    );
  }
}

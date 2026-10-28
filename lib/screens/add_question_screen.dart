// =============================================================================
// add_question_screen.dart — Déposer un souvenir dans la boîte
// -----------------------------------------------------------------------------
// Étape 1 : choisir la forme de la question (grille de cartes).
// Étape 2 : remplir le formulaire adapté, choisir qui peut répondre, déposer.
//
// Une fois déposée, la question quitte l'écran et ne peut plus être relue
// (sauf « ANNULER » dans les secondes qui suivent).
// =============================================================================


import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';

import '../data/repository.dart';
import '../models/models.dart';
import '../theme/sv_theme.dart';
import '../widgets/common.dart';

class AddQuestionScreen extends StatefulWidget {
  const AddQuestionScreen({super.key, required this.trip, required this.author});
  final Trip trip;
  final Profile author;

  @override
  State<AddQuestionScreen> createState() => _AddQuestionScreenState();
}

class _AddQuestionScreenState extends State<AddQuestionScreen> {
  /// Copie locale du voyage : on y ajoute les profils créés depuis cet écran.
  late Trip _trip = widget.trip;

  QuestionType? _type; // null = on est encore sur la grille des types

  // --- Champs du formulaire -----------------------------------------------
  final _prompt = TextEditingController();
  final _choices = List.generate(4, (_) => TextEditingController());
  int _correctIndex = 0;
  bool? _correctBool;
  String? _correctProfileId;
  final _number = TextEditingController();
  final _unit = TextEditingController();
  Uint8List? _photo;
  List<String> _answerers = const []; // vide = tout le monde
  bool _saving = false;

  @override
  void dispose() {
    // Les TextEditingController doivent être libérés à la fermeture de l'écran.
    _prompt.dispose();
    for (final c in _choices) {
      c.dispose();
    }
    _number.dispose();
    _unit.dispose();
    super.dispose();
  }

  // ---------------------------------------------------------------------------
  // Photo
  // ---------------------------------------------------------------------------
  Future<void> _pickPhoto(ImageSource source) async {
    // maxWidth + imageQuality : on réduit la photo (≈ 100-200 Ko) pour qu'elle
    // tienne dans un document Firebase (limite 1 Mo) et parte vite,
    // même avec un réseau de camping.
    final file = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 65,
    );
    if (file == null) return;
    final bytes = await file.readAsBytes();
    if (!mounted) return;
    setState(() => _photo = bytes);
  }

  // ---------------------------------------------------------------------------
  // Ajout d'un profil depuis « Qui peut répondre ? »
  // ---------------------------------------------------------------------------
  Future<void> _addProfile() async {
    final repo = AppScope.of(context).repo;
    final p = await showNewProfileSheet(context, colorSeed: _trip.profiles.length);
    if (p == null) return;
    await repo.addProfile(_trip.code, p);
    if (!mounted) return;
    setState(() {
      _trip = _trip.copyWith(profiles: [..._trip.profiles, p]);
      // Si on avait choisi « seulement certains », on ajoute le nouveau venu.
      if (_answerers.isNotEmpty) _answerers = [..._answerers, p.id];
    });
  }

  // ---------------------------------------------------------------------------
  // Vérification puis dépôt
  // ---------------------------------------------------------------------------
  String? _validate() {
    final type = _type!;
    if (type != QuestionType.photoFloue && _prompt.text.trim().isEmpty) {
      return type == QuestionType.quiADit ? 'Écris la phrase culte.' : 'Écris ta question.';
    }
    if (type == QuestionType.photoFloue && _photo == null) {
      return 'Ajoute une photo.';
    }
    if (type == QuestionType.qcm || type == QuestionType.photoFloue) {
      final filled = _choices.where((c) => c.text.trim().isNotEmpty).length;
      if (filled < 2) return 'Il faut au moins 2 réponses.';
      if (_choices[_correctIndex].text.trim().isEmpty) {
        return 'Coche la bonne réponse (elle ne peut pas être vide).';
      }
    }
    if (type == QuestionType.vraiFaux && _correctBool == null) {
      return 'Choisis Vrai ou Faux.';
    }
    if (type == QuestionType.quiADit && _correctProfileId == null) {
      return 'Qui a dit cette phrase ?';
    }
    if (type == QuestionType.estimation && _parseNumber() == null) {
      return 'Indique la bonne réponse (un nombre).';
    }
    return null;
  }

  /// Accepte « 12 », « 3,5 » ou « 3.5 ».
  double? _parseNumber() => double.tryParse(_number.text.trim().replaceAll(',', '.'));

  Future<void> _save() async {
    final error = _validate();
    if (error != null) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error)));
      return;
    }
    final type = _type!;

    // On ne garde que les réponses remplies, et on recalcule l'index de la bonne.
    final kept = <String>[];
    var correct = 0;
    for (var i = 0; i < _choices.length; i++) {
      final text = _choices[i].text.trim();
      if (text.isEmpty) continue;
      if (i == _correctIndex) correct = kept.length;
      kept.add(text);
    }
    final hasChoices = type == QuestionType.qcm || type == QuestionType.photoFloue;

    final question = Question(
      id: newId(),
      authorId: widget.author.id,
      type: type,
      prompt: _prompt.text.trim().isEmpty && type == QuestionType.photoFloue
          ? 'Qu’est-ce que c’est ?'
          : _prompt.text.trim(),
      choices: hasChoices ? kept : const [],
      correctIndex: hasChoices ? correct : 0,
      correctBool: type == QuestionType.vraiFaux ? _correctBool : null,
      correctProfileId: type == QuestionType.quiADit ? _correctProfileId : null,
      correctNumber: type == QuestionType.estimation ? _parseNumber() : null,
      unit: type == QuestionType.estimation && _unit.text.trim().isNotEmpty
          ? _unit.text.trim()
          : null,
      answerers: _answerers,
      createdAt: DateTime.now(),
    );

    setState(() => _saving = true);
    try {
      await AppScope.of(context).repo.addQuestion(_trip.code, question, _photo);
      if (!mounted) return;
      Navigator.pop(context, question); // on renvoie la question pour « ANNULER »
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('Dépôt impossible : $e'),
      ));
    }
  }

  // ---------------------------------------------------------------------------
  // Affichage
  // ---------------------------------------------------------------------------
  @override
  Widget build(BuildContext context) {
    // PopScope intercepte le bouton « retour » : depuis le formulaire,
    // on revient à la grille des types au lieu de quitter l'écran.
    return PopScope(
      canPop: _type == null,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _type = null);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Row(children: [
            ProfileAvatar(widget.author, size: 32),
            const SizedBox(width: 12),
            Flexible(child: Text(_type?.label ?? 'Nouveau souvenir')),
          ]),
        ),
        body: SafeArea(child: _type == null ? _buildTypeGrid() : _buildForm()),
        bottomNavigationBar: _type == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: FilledButton.icon(
                    icon: const Icon(Icons.lock),
                    label: Text(_saving ? 'ENVOI…' : 'DÉPOSER DANS LA BOÎTE'),
                    onPressed: _saving ? null : _save,
                  ),
                ),
              ),
      ),
    );
  }

  Widget _buildTypeGrid() {
    final t = Theme.of(context).textTheme;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Quelle forme de question ?', style: t.titleLarge),
        const SizedBox(height: 12),
        for (final type in QuestionType.values)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SvCard(
              onTap: () => setState(() => _type = type),
              child: Row(children: [
                Text(type.emoji, style: const TextStyle(fontSize: 32)),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(type.label,
                        style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    Text(type.hint, style: t.bodySmall),
                  ]),
                ),
                Icon(Icons.chevron_right, color: context.sv.inkMuted),
              ]),
            ),
          ),
      ],
    );
  }

  Widget _buildForm() {
    final t = Theme.of(context).textTheme;
    final type = _type!;
    final photoAllowed = type != QuestionType.quiADit && type != QuestionType.estimation;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // --- Photo -------------------------------------------------------------
        if (photoAllowed) ...[
          if (_photo != null)
            Stack(children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.memory(_photo!, height: 200, width: double.infinity, fit: BoxFit.cover),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: IconButton.filled(
                  tooltip: 'Retirer la photo',
                  icon: const Icon(Icons.close),
                  onPressed: () => setState(() => _photo = null),
                ),
              ),
            ])
          else
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_camera),
                  label: const Text('PHOTO'),
                  onPressed: () => _pickPhoto(ImageSource.camera),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.photo_library),
                  label: const Text('GALERIE'),
                  onPressed: () => _pickPhoto(ImageSource.gallery),
                ),
              ),
            ]),
          if (type == QuestionType.photoFloue)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pendant le quiz, la photo sera floue puis se dévoilera peu à peu. '
                'Bonus pour qui trouve avant la fin !',
                style: t.bodySmall,
              ),
            ),
          const SizedBox(height: 20),
        ],

        // --- Énoncé ------------------------------------------------------------
        TextField(
          controller: _prompt,
          maxLines: null, // le champ grandit avec le texte
          textCapitalization: TextCapitalization.sentences,
          decoration: InputDecoration(
            labelText: switch (type) {
              QuestionType.quiADit => 'La phrase culte',
              QuestionType.vraiFaux => 'L’affirmation',
              QuestionType.photoFloue => 'Question (facultatif)',
              _ => 'Ta question',
            },
            hintText: switch (type) {
              QuestionType.qcm => 'Où a-t-on pique-niqué ce midi ?',
              QuestionType.vraiFaux => 'Gaby a vu une méduse.',
              QuestionType.photoFloue => 'Qu’est-ce que c’est ?',
              QuestionType.quiADit => '« On est bientôt arrivés ? »',
              QuestionType.estimation => 'Combien de crêpes Tom a-t-il mangées ?',
            },
          ),
        ),
        const SizedBox(height: 20),

        // --- Réponses selon le type --------------------------------------------
        ..._buildAnswerFields(type),
        const SizedBox(height: 28),

        // --- Qui peut répondre ? --------------------------------------------------
        Text('Qui peut répondre ?', style: t.titleLarge),
        const SizedBox(height: 4),
        Text('${widget.author.name} ne répond pas à sa propre question.', style: t.bodySmall),
        const SizedBox(height: 12),
        AnswerersPicker(
          trip: _trip,
          authorId: widget.author.id,
          selected: _answerers,
          onChanged: (ids) => setState(() => _answerers = ids),
          onAddProfile: _addProfile,
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  List<Widget> _buildAnswerFields(QuestionType type) {
    final t = Theme.of(context).textTheme;
    switch (type) {
      case QuestionType.qcm:
      case QuestionType.photoFloue:
        return [
          Text('Réponses proposées', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          Text('Coche la bonne. Les cases vides sont ignorées.', style: t.bodySmall),
          const SizedBox(height: 8),
          for (var i = 0; i < _choices.length; i++)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(children: [
                // Bouton rond : coché = bonne réponse.
                IconButton(
                  tooltip: 'Bonne réponse',
                  onPressed: () => setState(() => _correctIndex = i),
                  icon: Icon(
                    i == _correctIndex ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: i == _correctIndex ? context.sv.teal : context.sv.inkMuted,
                  ),
                ),
                Expanded(
                  child: TextField(
                    controller: _choices[i],
                    textCapitalization: TextCapitalization.sentences,
                    decoration: InputDecoration(
                      hintText: i < 2 ? 'Réponse ${i + 1}' : 'Réponse ${i + 1} (facultatif)',
                    ),
                  ),
                ),
              ]),
            ),
        ];

      case QuestionType.vraiFaux:
        return [
          Text('La bonne réponse', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(child: _bigChoice('Vrai', _correctBool == true, () => setState(() => _correctBool = true))),
            const SizedBox(width: 12),
            Expanded(child: _bigChoice('Faux', _correctBool == false, () => setState(() => _correctBool = false))),
          ]),
        ];

      case QuestionType.quiADit:
        return [
          Text('Qui l’a dit ?', style: t.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(children: [
            for (final p in _trip.profiles)
              ProfileTile(
                profile: p,
                size: 48,
                selected: p.id == _correctProfileId,
                onTap: () => setState(() => _correctProfileId = p.id),
              ),
          ]),
        ];

      case QuestionType.estimation:
        return [
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 2,
              child: TextField(
                controller: _number,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
                decoration: const InputDecoration(labelText: 'Bonne réponse'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 3,
              child: TextField(
                controller: _unit,
                decoration: const InputDecoration(labelText: 'Unité (facultatif)', hintText: 'crêpes'),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          Text('Pendant le quiz, le plus proche gagne le point.', style: t.bodySmall),
        ];
    }
  }

  /// Gros bouton sélectionnable (Vrai / Faux).
  Widget _bigChoice(String label, bool selected, VoidCallback onTap) {
    return SvCard(
      onTap: onTap,
      color: selected ? context.sv.tealSoft : null,
      child: Center(
        child: Text(
          label,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
              color: selected ? context.sv.ink : context.sv.inkMuted),
        ),
      ),
    );
  }
}

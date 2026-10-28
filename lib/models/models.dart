// =============================================================================
// models.dart — Les « objets » de Quiz'Vacances
// -----------------------------------------------------------------------------
// Un modèle, c'est une simple classe Dart qui décrit une donnée de l'appli :
//   - Profile  : un membre de la famille (Papa, Gaby, Tom…)
//   - Trip     : un voyage = une « boîte à souvenirs »
//   - Question : un souvenir transformé en question de quiz
//   - QuizResult : les scores d'une partie
//
// Chaque classe sait se convertir en Map (toMap) et se recréer depuis une Map
// (fromMap). C'est ce format Map<String, dynamic> que Firebase (Firestore) et
// le stockage local savent enregistrer.
// =============================================================================

/// Les couleurs proposées pour les avatars des profils.
/// On stocke juste l'index (0, 1, 2…) dans la base, la vraie couleur est
/// choisie dans le thème (voir sv_theme.dart → SvColors.profilePalette).
const int kProfileColorCount = 6;

// -----------------------------------------------------------------------------
// PROFIL
// -----------------------------------------------------------------------------
class Profile {
  final String id; // identifiant unique (généré à la création)
  final String name; // prénom affiché
  final String emoji; // petit avatar, ex. « 🦊 »
  final int color; // index dans la palette des avatars
  final String? pin; // code secret à 4 chiffres (facultatif)

  const Profile({
    required this.id,
    required this.name,
    required this.emoji,
    required this.color,
    this.pin,
  });

  /// Vrai si le profil est protégé par un code.
  bool get hasPin => pin != null && pin!.isNotEmpty;

  Map<String, dynamic> toMap() => {
        'id': id,
        'name': name,
        'emoji': emoji,
        'color': color,
        if (hasPin) 'pin': pin,
      };

  factory Profile.fromMap(Map<String, dynamic> m) => Profile(
        id: m['id'] as String,
        name: m['name'] as String? ?? '?',
        emoji: m['emoji'] as String? ?? '🙂',
        color: (m['color'] as num?)?.toInt() ?? 0,
        pin: m['pin'] as String?,
      );
}

// -----------------------------------------------------------------------------
// VOYAGE
// -----------------------------------------------------------------------------

/// Les 3 étapes de la vie d'un voyage.
enum TripStatus {
  /// On collecte les souvenirs : les questions sont scellées, invisibles.
  collecte,

  /// Le quiz a été lancé : la boîte est ouverte, on peut jouer.
  quiz,

  /// Au moins une partie a été jouée : le carnet de souvenirs est consultable.
  termine,
}

class Trip {
  /// Le code à 6 lettres sert À LA FOIS d'identifiant et de code d'invitation.
  /// Ex. « KXPR4M ». Il n'y a pas de 0/O ni de 1/I pour éviter les confusions.
  final String code;
  final String title; // « Week-end à Étretat »
  final String emoji; // « 🏖️ »
  final DateTime createdAt;
  final TripStatus status;
  final List<Profile> profiles; // tous les membres du voyage
  final int questionCount; // nombre total de souvenirs déposés
  final Map<String, int> countByAuthor; // profilId → nombre de souvenirs
  final List<QuizResult> results; // historique des parties jouées

  const Trip({
    required this.code,
    required this.title,
    required this.emoji,
    required this.createdAt,
    required this.status,
    required this.profiles,
    required this.questionCount,
    required this.countByAuthor,
    required this.results,
  });

  /// Retrouve un profil par son id (ou null s'il n'existe pas/plus).
  Profile? profileById(String id) {
    for (final p in profiles) {
      if (p.id == id) return p;
    }
    return null;
  }

  Trip copyWith({
    TripStatus? status,
    List<Profile>? profiles,
    int? questionCount,
    Map<String, int>? countByAuthor,
    List<QuizResult>? results,
  }) =>
      Trip(
        code: code,
        title: title,
        emoji: emoji,
        createdAt: createdAt,
        status: status ?? this.status,
        profiles: profiles ?? this.profiles,
        questionCount: questionCount ?? this.questionCount,
        countByAuthor: countByAuthor ?? this.countByAuthor,
        results: results ?? this.results,
      );

  Map<String, dynamic> toMap() => {
        'code': code,
        'title': title,
        'emoji': emoji,
        'createdAt': createdAt.millisecondsSinceEpoch,
        'status': status.name, // « collecte », « quiz » ou « termine »
        'profiles': profiles.map((p) => p.toMap()).toList(),
        'questionCount': questionCount,
        'countByAuthor': countByAuthor,
        'results': results.map((r) => r.toMap()).toList(),
      };

  factory Trip.fromMap(Map<String, dynamic> m) => Trip(
        code: m['code'] as String,
        title: m['title'] as String? ?? 'Voyage',
        emoji: m['emoji'] as String? ?? '🧳',
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['createdAt'] as num?)?.toInt() ?? 0),
        // TripStatus.values.byName transforme le texte « quiz » en TripStatus.quiz
        status: TripStatus.values.byName(m['status'] as String? ?? 'collecte'),
        profiles: ((m['profiles'] as List?) ?? [])
            .map((e) => Profile.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
        questionCount: (m['questionCount'] as num?)?.toInt() ?? 0,
        countByAuthor: ((m['countByAuthor'] as Map?) ?? {}).map(
            (k, v) => MapEntry(k as String, (v as num).toInt())),
        results: ((m['results'] as List?) ?? [])
            .map((e) => QuizResult.fromMap(Map<String, dynamic>.from(e as Map)))
            .toList(),
      );
}

// -----------------------------------------------------------------------------
// QUESTION
// -----------------------------------------------------------------------------

/// Les différentes formes de questions.
enum QuestionType {
  qcm, // choix multiples (2 à 4 réponses), photo facultative
  vraiFaux, // vrai ou faux
  photoFloue, // une photo floue qui se dévoile + choix multiples
  quiADit, // « Qui a dit ça ? » → la réponse est un membre de la famille
  estimation, // un nombre à deviner (« Combien de glaces ? »)
}

/// Libellés et petites descriptions affichés dans l'appli.
extension QuestionTypeInfo on QuestionType {
  String get label => switch (this) {
        QuestionType.qcm => 'Choix multiples',
        QuestionType.vraiFaux => 'Vrai ou faux',
        QuestionType.photoFloue => 'Photo mystère',
        QuestionType.quiADit => 'Qui a dit ça ?',
        QuestionType.estimation => 'Estimation',
      };

  String get hint => switch (this) {
        QuestionType.qcm => '2 à 4 réponses, une seule est juste.',
        QuestionType.vraiFaux => 'Une affirmation, vraie ou fausse.',
        QuestionType.photoFloue => 'La photo se dévoile petit à petit.',
        QuestionType.quiADit => 'Une phrase culte, à rendre à son auteur.',
        QuestionType.estimation => 'Un nombre : le plus proche gagne.',
      };

  String get emoji => switch (this) {
        QuestionType.qcm => '🔤',
        QuestionType.vraiFaux => '⚖️',
        QuestionType.photoFloue => '📷',
        QuestionType.quiADit => '💬',
        QuestionType.estimation => '🔢',
      };
}

class Question {
  final String id;
  final String authorId; // profil qui a posé la question
  final QuestionType type;
  final String prompt; // l'énoncé (ou la phrase culte pour quiADit)
  final List<String> choices; // réponses proposées (qcm, photoFloue)
  final int correctIndex; // index de la bonne réponse dans choices
  final bool? correctBool; // vraiFaux
  final String? correctProfileId; // quiADit
  final double? correctNumber; // estimation
  final String? unit; // estimation : « glaces », « km »…
  final String? photoUrl; // URL Firebase ou « data:… » en mode démo
  final List<String> answerers; // vide = tout le monde (sauf l'auteur)
  final DateTime createdAt;

  const Question({
    required this.id,
    required this.authorId,
    required this.type,
    required this.prompt,
    this.choices = const [],
    this.correctIndex = 0,
    this.correctBool,
    this.correctProfileId,
    this.correctNumber,
    this.unit,
    this.photoUrl,
    this.answerers = const [],
    required this.createdAt,
  });

  /// Est-ce que ce profil a le droit de répondre à cette question ?
  /// - l'auteur ne répond jamais à sa propre question ;
  /// - si answerers est vide, tout le monde peut répondre ;
  /// - sinon seuls les profils listés.
  bool canAnswer(String profileId) {
    if (profileId == authorId) return false;
    if (answerers.isEmpty) return true;
    return answerers.contains(profileId);
  }

  /// Le texte de la bonne réponse, pour l'afficher au moment de la révélation.
  String correctLabel(Trip trip) => switch (type) {
        QuestionType.qcm ||
        QuestionType.photoFloue =>
          choices.isEmpty ? '?' : choices[correctIndex],
        QuestionType.vraiFaux => correctBool == true ? 'Vrai' : 'Faux',
        QuestionType.quiADit =>
          trip.profileById(correctProfileId ?? '')?.name ?? '?',
        QuestionType.estimation =>
          '${formatNumber(correctNumber ?? 0)}${unit == null || unit!.isEmpty ? '' : ' $unit'}',
      };

  Question copyWith({String? photoUrl}) => Question(
        id: id,
        authorId: authorId,
        type: type,
        prompt: prompt,
        choices: choices,
        correctIndex: correctIndex,
        correctBool: correctBool,
        correctProfileId: correctProfileId,
        correctNumber: correctNumber,
        unit: unit,
        photoUrl: photoUrl ?? this.photoUrl,
        answerers: answerers,
        createdAt: createdAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'authorId': authorId,
        'type': type.name,
        'prompt': prompt,
        'choices': choices,
        'correctIndex': correctIndex,
        if (correctBool != null) 'correctBool': correctBool,
        if (correctProfileId != null) 'correctProfileId': correctProfileId,
        if (correctNumber != null) 'correctNumber': correctNumber,
        if (unit != null) 'unit': unit,
        if (photoUrl != null) 'photoUrl': photoUrl,
        'answerers': answerers,
        'createdAt': createdAt.millisecondsSinceEpoch,
      };

  factory Question.fromMap(Map<String, dynamic> m) => Question(
        id: m['id'] as String,
        authorId: m['authorId'] as String,
        type: QuestionType.values.byName(m['type'] as String),
        prompt: m['prompt'] as String? ?? '',
        choices: List<String>.from(m['choices'] as List? ?? const []),
        correctIndex: (m['correctIndex'] as num?)?.toInt() ?? 0,
        correctBool: m['correctBool'] as bool?,
        correctProfileId: m['correctProfileId'] as String?,
        correctNumber: (m['correctNumber'] as num?)?.toDouble(),
        unit: m['unit'] as String?,
        photoUrl: m['photoUrl'] as String?,
        answerers: List<String>.from(m['answerers'] as List? ?? const []),
        createdAt: DateTime.fromMillisecondsSinceEpoch(
            (m['createdAt'] as num?)?.toInt() ?? 0),
      );
}

// -----------------------------------------------------------------------------
// RÉSULTAT D'UNE PARTIE
// -----------------------------------------------------------------------------
class QuizResult {
  final DateTime playedAt;
  final Map<String, int> scores; // profilId → points

  const QuizResult({required this.playedAt, required this.scores});

  Map<String, dynamic> toMap() => {
        'playedAt': playedAt.millisecondsSinceEpoch,
        'scores': scores,
      };

  factory QuizResult.fromMap(Map<String, dynamic> m) => QuizResult(
        playedAt: DateTime.fromMillisecondsSinceEpoch(
            (m['playedAt'] as num?)?.toInt() ?? 0),
        scores: ((m['scores'] as Map?) ?? {})
            .map((k, v) => MapEntry(k as String, (v as num).toInt())),
      );
}

// -----------------------------------------------------------------------------
// Petits utilitaires
// -----------------------------------------------------------------------------

/// Affiche 12.0 comme « 12 » et 3.5 comme « 3,5 » (virgule à la française).
String formatNumber(double n) {
  if (!n.isFinite) return '∞'; // nombre délirant tapé au clavier
  if (n == n.roundToDouble()) return n.toInt().toString();
  return n.toString().replaceAll('.', ',');
}

/// Jours de la semaine et mois en français, sans dépendre d'un paquet.
const _jours = ['lundi', 'mardi', 'mercredi', 'jeudi', 'vendredi', 'samedi', 'dimanche'];
const _mois = [
  'janvier', 'février', 'mars', 'avril', 'mai', 'juin',
  'juillet', 'août', 'septembre', 'octobre', 'novembre', 'décembre'
];

/// « samedi 24 octobre »
String formatDay(DateTime d) => '${_jours[d.weekday - 1]} ${d.day} ${_mois[d.month - 1]}';

/// « 24 oct. 2026 »
String formatShortDate(DateTime d) =>
    '${d.day} ${_mois[d.month - 1].substring(0, 3)}. ${d.year}';

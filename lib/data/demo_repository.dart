// =============================================================================
// demo_repository.dart — Le moteur « mode démo » (tout sur ce téléphone)
// -----------------------------------------------------------------------------
// Utilisé tant que Firebase n'est pas configuré. Tout est enregistré dans
// SharedPreferences sous forme de texte JSON. Les photos sont transformées en
// texte « data:image/jpeg;base64,… » pour tenir dans ce même coffre.
//
// Limite : un seul téléphone. Pour jouer à plusieurs téléphones, il faut
// brancher Firebase (voir README.md).
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import '../models/models.dart';
import 'repository.dart';

class DemoRepository implements QuizRepository {
  DemoRepository(this._device);
  final DeviceState _device;

  // Un StreamController « broadcast » permet à plusieurs écrans d'écouter
  // les changements en même temps. À chaque modification, on y pousse un
  // signal et les écrans se redessinent.
  final _changes = StreamController<void>.broadcast();

  @override
  bool get isShared => false;

  // --- Lecture / écriture brute dans le coffre -----------------------------
  Trip? _readTrip(String code) {
    final raw = _device.prefs.getString('demo_trip_$code');
    if (raw == null) return null;
    return Trip.fromMap(jsonDecode(raw) as Map<String, dynamic>);
  }

  Future<void> _writeTrip(Trip trip) async {
    await _device.prefs.setString('demo_trip_${trip.code}', jsonEncode(trip.toMap()));
    _changes.add(null); // on prévient les écrans
  }

  List<Question> _readQuestions(String code) {
    final raw = _device.prefs.getString('demo_questions_$code');
    if (raw == null) return [];
    return (jsonDecode(raw) as List)
        .map((e) => Question.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> _writeQuestions(String code, List<Question> qs) =>
      _device.prefs.setString(
          'demo_questions_$code', jsonEncode(qs.map((q) => q.toMap()).toList()));

  // --- Flux en direct --------------------------------------------------------
  // « async* » + « yield » : une fonction qui produit une suite de valeurs.
  // On envoie l'état actuel, puis un nouvel état à chaque changement.
  @override
  Stream<List<Trip>> watchMyTrips() async* {
    List<Trip> snapshot() =>
        _device.tripCodes.map(_readTrip).whereType<Trip>().toList();
    yield snapshot();
    await for (final _ in _changes.stream) {
      yield snapshot();
    }
  }

  @override
  Stream<Trip?> watchTrip(String code) async* {
    yield _readTrip(code);
    await for (final _ in _changes.stream) {
      yield _readTrip(code);
    }
  }

  // --- Actions ---------------------------------------------------------------
  @override
  Future<Trip> createTrip({
    required String title,
    required String emoji,
    required List<Profile> profiles,
  }) async {
    final trip = Trip(
      code: newTripCode(),
      title: title,
      emoji: emoji,
      createdAt: DateTime.now(),
      status: TripStatus.collecte,
      profiles: profiles,
      questionCount: 0,
      countByAuthor: const {},
      results: const [],
    );
    await _device.rememberTrip(trip.code);
    await _writeTrip(trip);
    return trip;
  }

  @override
  Future<Trip?> joinTrip(String code) async {
    final trip = _readTrip(code);
    if (trip != null) {
      await _device.rememberTrip(code);
      _changes.add(null);
    }
    return trip;
  }

  @override
  Future<void> addProfile(String code, Profile profile) async {
    final trip = _readTrip(code)!;
    await _writeTrip(trip.copyWith(profiles: [...trip.profiles, profile]));
  }

  @override
  Future<void> addQuestion(String code, Question question, Uint8List? photo) async {
    // La photo devient un texte base64 rangé directement dans la question.
    final q = photo == null
        ? question
        : question.copyWith(photoUrl: 'data:image/jpeg;base64,${base64Encode(photo)}');
    await _writeQuestions(code, [..._readQuestions(code), q]);

    // On met à jour les compteurs visibles par tous.
    final trip = _readTrip(code)!;
    final counts = Map<String, int>.from(trip.countByAuthor);
    counts[q.authorId] = (counts[q.authorId] ?? 0) + 1;
    await _writeTrip(trip.copyWith(
        questionCount: trip.questionCount + 1, countByAuthor: counts));
  }

  @override
  Future<void> undoQuestion(String code, Question question) async {
    await _writeQuestions(
        code, _readQuestions(code).where((q) => q.id != question.id).toList());
    final trip = _readTrip(code)!;
    final counts = Map<String, int>.from(trip.countByAuthor);
    counts[question.authorId] = ((counts[question.authorId] ?? 1) - 1).clamp(0, 9999);
    await _writeTrip(trip.copyWith(
        questionCount: (trip.questionCount - 1).clamp(0, 9999),
        countByAuthor: counts));
  }

  @override
  Future<void> startQuiz(String code) async {
    final trip = _readTrip(code)!;
    await _writeTrip(trip.copyWith(status: TripStatus.quiz));
  }

  @override
  Future<List<Question>> loadQuestions(String code) async {
    // Même règle que côté Firebase : rien à lire tant que la boîte est scellée.
    final trip = _readTrip(code);
    if (trip == null || trip.status == TripStatus.collecte) return [];
    return _readQuestions(code);
  }

  @override
  Future<void> saveResult(String code, QuizResult result) async {
    final trip = _readTrip(code)!;
    await _writeTrip(trip.copyWith(
        status: TripStatus.termine, results: [...trip.results, result]));
  }

  @override
  Future<void> forgetTrip(String code) async {
    await _device.forgetTrip(code);
    _changes.add(null);
  }
}

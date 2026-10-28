// =============================================================================
// firebase_repository.dart — Le moteur partagé (plusieurs téléphones)
// -----------------------------------------------------------------------------
// Organisation des données dans Firebase :
//
//   Firestore (base de données)
//   └── trips/{CODE}                 ← un document par voyage (le code = l'id)
//       ├── title, emoji, status, profiles, questionCount, countByAuthor…
//       ├── memberUids: [uid1, uid2] ← les téléphones qui ont rejoint
//       └── questions/{id}           ← les souvenirs, ILLISIBLES tant que
//                                       status == "collecte" (voir firestore.rules)
//
// Les photos sont rangées DANS la question elle-même, en texte base64
// (« data:image/jpeg;base64,… »). Elles sont réduites à ~100-200 Ko, bien
// sous la limite de 1 Mo par document. Avantages :
//   - pas besoin de Firebase Storage (qui exige désormais une carte bancaire) ;
//   - la photo profite de la même règle de secret que la question ;
//   - hors ligne, la photo part avec la question dès que ça capte.
//
// Chaque téléphone se connecte de façon « anonyme » (sans compte ni mot de
// passe) : Firebase lui donne juste un identifiant unique (uid). C'est cet uid
// que les règles de sécurité utilisent pour savoir qui a le droit de quoi.
// =============================================================================

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart' show debugPrint;

import '../models/models.dart';
import 'repository.dart';

class FirebaseRepository implements QuizRepository {
  FirebaseRepository(this._device);
  final DeviceState _device;

  final _db = FirebaseFirestore.instance;

  @override
  bool get isShared => true;

  /// Connexion anonyme au démarrage (une seule fois par installation).
  static Future<void> signIn() async {
    if (FirebaseAuth.instance.currentUser == null) {
      await FirebaseAuth.instance.signInAnonymously();
    }
  }

  String get _uid => FirebaseAuth.instance.currentUser!.uid;

  DocumentReference<Map<String, dynamic>> _tripRef(String code) =>
      _db.collection('trips').doc(code);

  // --- Flux en direct --------------------------------------------------------
  /// Signal local : « la liste des voyages masqués a changé ».
  final _hiddenChanged = StreamController<void>.broadcast();

  @override
  Stream<List<Trip>> watchMyTrips() async* {
    List<Trip> lastTrips = [];

    // On masque ceux que l'utilisateur a retirés de sa liste,
    // et on trie du plus récent au plus ancien.
    List<Trip> visible() {
      final hidden = _device.prefs.getStringList('hiddenTrips') ?? [];
      return lastTrips.where((t) => !hidden.contains(t.code)).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    }

    // On fusionne deux sources d'événements dans un seul flux :
    //   - les changements Firebase (un voyage modifié, rejoint…) ;
    //   - le masquage local d'un voyage.
    final merged = StreamController<void>();
    final sub1 = _db
        .collection('trips')
        // « array-contains » : tous les voyages dont la liste memberUids
        // contient l'uid de ce téléphone.
        .where('memberUids', arrayContains: _uid)
        .snapshots()
        .listen((snap) {
      lastTrips = snap.docs.map((d) => Trip.fromMap(d.data())).toList();
      merged.add(null);
    }, onError: (Object e) => merged.addError(e)); // erreur → affichée à l'accueil
    final sub2 = _hiddenChanged.stream.listen((_) => merged.add(null));
    try {
      await for (final _ in merged.stream) {
        yield visible();
      }
    } finally {
      // Quand l'écran n'écoute plus, on coupe proprement les abonnements.
      await sub1.cancel();
      await sub2.cancel();
    }
  }

  @override
  Stream<Trip?> watchTrip(String code) => _tripRef(code)
      .snapshots()
      .map((d) => d.exists ? Trip.fromMap(d.data()!) : null);

  // --- Actions ---------------------------------------------------------------
  @override
  Future<Trip> createTrip({
    required String title,
    required String emoji,
    required List<Profile> profiles,
  }) async {
    // On tire un code au hasard ; s'il existe déjà (très peu probable), on recommence.
    String code;
    do {
      code = newTripCode();
    } while ((await _tripRef(code).get()).exists);

    final trip = Trip(
      code: code,
      title: title,
      emoji: emoji,
      createdAt: DateTime.now(),
      status: TripStatus.collecte,
      profiles: profiles,
      questionCount: 0,
      countByAuthor: const {},
      results: const [],
    );
    await _tripRef(code).set({...trip.toMap(), 'memberUids': [_uid]});
    await _device.rememberTrip(code);
    return trip;
  }

  @override
  Future<Trip?> joinTrip(String code) async {
    final doc = await _tripRef(code).get();
    if (!doc.exists) return null;
    // FieldValue.arrayUnion ajoute notre uid sans écraser ceux des autres.
    await _tripRef(code).update({
      'memberUids': FieldValue.arrayUnion([_uid]),
    });
    await _device.rememberTrip(code);
    await _unhide(code);
    return Trip.fromMap(doc.data()!);
  }

  @override
  Future<void> addProfile(String code, Profile profile) async {
    // Même principe que pour les questions : fonctionne aussi hors ligne.
    unawaited(_tripRef(code).update({
      'profiles': FieldValue.arrayUnion([profile.toMap()]),
    }).catchError((Object e) {
      debugPrint('Ajout du profil refusé : $e');
    }));
  }

  @override
  Future<void> addQuestion(String code, Question question, Uint8List? photo) async {
    // La photo devient du texte et voyage avec la question.
    final q = photo == null
        ? question
        : question.copyWith(photoUrl: 'data:image/jpeg;base64,${base64Encode(photo)}');

    // Un « batch » regroupe plusieurs écritures : soit tout passe, soit rien.
    final batch = _db.batch();
    // « uid » = le téléphone qui a déposé : seul lui pourra « ANNULER ».
    batch.set(_tripRef(code).collection('questions').doc(q.id), {...q.toMap(), 'uid': _uid});
    batch.update(_tripRef(code), {
      // FieldValue.increment évite les conflits si deux téléphones
      // déposent une question au même moment.
      'questionCount': FieldValue.increment(1),
      'countByAuthor.${q.authorId}': FieldValue.increment(1),
    });
    // ⚠️ On n'attend PAS (pas de « await ») la confirmation du serveur :
    // sans réseau, Firestore garde l'écriture en file d'attente et l'enverra
    // tout seul dès que ça capte. Attendre bloquerait l'écran hors ligne.
    // « unawaited » dit explicitement à Dart : c'est voulu.
    unawaited(batch.commit().catchError((Object e) {
      debugPrint('Envoi de la question refusé : $e');
    }));
  }

  @override
  Future<void> undoQuestion(String code, Question question) async {
    final batch = _db.batch();
    batch.delete(_tripRef(code).collection('questions').doc(question.id));
    batch.update(_tripRef(code), {
      'questionCount': FieldValue.increment(-1),
      'countByAuthor.${question.authorId}': FieldValue.increment(-1),
    });
    unawaited(batch.commit().catchError((Object e) {
      debugPrint('Annulation refusée : $e');
    }));
  }

  @override
  Future<void> startQuiz(String code) async {
    // Ici on ATTEND le serveur : tant qu'il n'a pas enregistré l'ouverture,
    // les règles refuseraient la lecture des questions. Il faut donc du réseau
    // pour ouvrir la boîte (le timeout évite d'attendre indéfiniment).
    await _tripRef(code)
        .update({'status': TripStatus.quiz.name})
        .timeout(const Duration(seconds: 15));
  }

  @override
  Future<List<Question>> loadQuestions(String code) async {
    // Source.server : on lit le serveur, pas le cache du téléphone. Le cache
    // ne contiendrait que les questions déposées ICI : le quiz serait incomplet.
    // Sans réseau, on obtient une erreur claire (affichée avec « RÉESSAYER »).
    final snap = await _tripRef(code)
        .collection('questions')
        .get(const GetOptions(source: Source.server));
    return snap.docs.map((d) => Question.fromMap(d.data())).toList();
  }

  @override
  Future<void> saveResult(String code, QuizResult result) async {
    unawaited(_tripRef(code).update({
      'status': TripStatus.termine.name,
      'results': FieldValue.arrayUnion([result.toMap()]),
    }).catchError((Object e) {
      debugPrint('Enregistrement des scores refusé : $e');
    }));
  }

  @override
  Future<void> forgetTrip(String code) async {
    // Le voyage reste dans Firebase pour les autres : on le masque juste ici.
    final hidden = _device.prefs.getStringList('hiddenTrips') ?? [];
    if (!hidden.contains(code)) {
      await _device.prefs.setStringList('hiddenTrips', [...hidden, code]);
    }
    await _device.forgetTrip(code);
    _hiddenChanged.add(null); // la liste se redessine
  }

  Future<void> _unhide(String code) async {
    final hidden = _device.prefs.getStringList('hiddenTrips') ?? [];
    await _device.prefs.setStringList(
        'hiddenTrips', hidden.where((c) => c != code).toList());
    _hiddenChanged.add(null);
  }
}

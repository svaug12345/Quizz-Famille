// =============================================================================
// repository.dart — Le « contrat » d'accès aux données
// -----------------------------------------------------------------------------
// L'appli ne parle JAMAIS directement à Firebase. Elle passe par cette classe
// abstraite QuizRepository, qui décrit CE QU'ON PEUT FAIRE (créer un voyage,
// déposer une question…) sans dire COMMENT.
//
// Deux implémentations existent :
//   - FirebaseRepository : la vraie, partagée entre plusieurs téléphones ;
//   - DemoRepository     : tout reste sur ce téléphone (pratique pour tester
//                          tant que Firebase n'est pas configuré).
//
// Avantage : on peut changer de « moteur » sans toucher aux écrans.
// =============================================================================

import 'dart:math';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/models.dart';

abstract class QuizRepository {
  /// true si les données sont partagées entre téléphones (Firebase).
  bool get isShared;

  /// Les voyages créés ou rejoints sur CE téléphone, mis à jour en direct.
  Stream<List<Trip>> watchMyTrips();

  /// Un voyage précis, mis à jour en direct (compteur de souvenirs, statut…).
  Stream<Trip?> watchTrip(String code);

  /// Crée un nouveau voyage avec ses premiers profils.
  Future<Trip> createTrip({
    required String title,
    required String emoji,
    required List<Profile> profiles,
  });

  /// Rejoint un voyage existant grâce à son code. Renvoie null si introuvable.
  Future<Trip?> joinTrip(String code);

  /// Ajoute un profil (ex. Mamie qui arrive samedi).
  Future<void> addProfile(String code, Profile profile);

  /// Dépose une question dans la boîte. Elle devient aussitôt illisible.
  /// [photo] : les octets de l'image (JPEG), ou null.
  Future<void> addQuestion(String code, Question question, Uint8List? photo);

  /// Retire la dernière question déposée (bouton « Annuler » juste après).
  Future<void> undoQuestion(String code, Question question);

  /// Ouvre la boîte : plus personne ne peut ajouter de souvenirs.
  Future<void> startQuiz(String code);

  /// Lit toutes les questions. Ne fonctionne qu'une fois le quiz lancé
  /// (Firebase refuse la lecture avant, grâce aux règles de sécurité).
  Future<List<Question>> loadQuestions(String code);

  /// Enregistre les scores d'une partie.
  Future<void> saveResult(String code, QuizResult result);

  /// Retire le voyage de la liste de ce téléphone (sans le supprimer pour les autres).
  Future<void> forgetTrip(String code);
}

// -----------------------------------------------------------------------------
// Ce que le TÉLÉPHONE retient localement, quel que soit le moteur.
// -----------------------------------------------------------------------------
// SharedPreferences est un petit coffre clé → valeur, propre à chaque appareil.
// On y garde :
//   - les codes des voyages connus de ce téléphone ;
//   - pour chaque voyage, les profils « présents » sur ce téléphone
//     (un même téléphone peut porter Papa ET Tom).
class DeviceState {
  DeviceState(this._prefs);
  final SharedPreferences _prefs;

  static Future<DeviceState> load() async =>
      DeviceState(await SharedPreferences.getInstance());

  // --- Voyages connus -------------------------------------------------------
  List<String> get tripCodes => _prefs.getStringList('tripCodes') ?? [];

  Future<void> rememberTrip(String code) async {
    final codes = tripCodes;
    if (!codes.contains(code)) {
      codes.insert(0, code); // le plus récent en premier
      await _prefs.setStringList('tripCodes', codes);
    }
  }

  Future<void> forgetTrip(String code) async {
    final codes = tripCodes..remove(code);
    await _prefs.setStringList('tripCodes', codes);
  }

  // --- Profils portés par ce téléphone, par voyage ---------------------------
  List<String> localProfiles(String code) =>
      _prefs.getStringList('localProfiles_$code') ?? [];

  Future<void> addLocalProfile(String code, String profileId) async {
    final ids = localProfiles(code);
    if (!ids.contains(profileId)) {
      ids.add(profileId);
      await _prefs.setStringList('localProfiles_$code', ids);
    }
  }

  Future<void> removeLocalProfile(String code, String profileId) async {
    final ids = localProfiles(code)..remove(profileId);
    await _prefs.setStringList('localProfiles_$code', ids);
  }

  // Accès direct au coffre (utilisé par le mode démo pour ses données).
  SharedPreferences get prefs => _prefs;
}

// -----------------------------------------------------------------------------
// Générateurs d'identifiants
// -----------------------------------------------------------------------------
final _rng = Random.secure();

/// Code de voyage à 6 caractères, sans caractères ambigus (0/O, 1/I/L).
String newTripCode() {
  const alphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';
  return List.generate(6, (_) => alphabet[_rng.nextInt(alphabet.length)]).join();
}

/// Identifiant aléatoire de 16 caractères pour profils et questions.
String newId() {
  const alphabet = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return List.generate(16, (_) => alphabet[_rng.nextInt(alphabet.length)]).join();
}

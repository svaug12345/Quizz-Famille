// =============================================================================
// widget_test.dart — Tests automatiques de Quiz'Vacances
// -----------------------------------------------------------------------------
// Se lancent avec :  flutter test
//
// « flutter create » avait généré ici un test d'exemple (un compteur « MyApp »)
// qui n'existe pas dans notre appli → erreur d'analyse. On le remplace par des
// tests qui vérifient les règles importantes du jeu, sans écran ni réseau :
//   - qui a le droit de répondre à une question ;
//   - l'affichage des nombres à la française ;
//   - le SECRET de la boîte en mode démo (rien de lisible avant l'ouverture).
// =============================================================================

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quiz_vacances/data/demo_repository.dart';
import 'package:quiz_vacances/data/repository.dart';
import 'package:quiz_vacances/models/models.dart';

void main() {
  // Trois profils de test, réutilisés partout.
  const papa = Profile(id: 'p1', name: 'Papa', emoji: '🦊', color: 0);
  const gaby = Profile(id: 'p2', name: 'Gaby', emoji: '🐬', color: 1);
  const tom = Profile(id: 'p3', name: 'Tom', emoji: '🐢', color: 2);

  group('Question.canAnswer', () {
    test("l'auteur ne répond jamais à sa propre question", () {
      final q = Question(
          id: 'q', authorId: 'p1', type: QuestionType.vraiFaux,
          prompt: 'Il a plu ?', correctBool: false, createdAt: DateTime(2026));
      expect(q.canAnswer('p1'), isFalse);
      expect(q.canAnswer('p2'), isTrue); // liste vide = tout le monde
    });

    test('seuls les profils choisis peuvent répondre', () {
      final q = Question(
          id: 'q', authorId: 'p1', type: QuestionType.vraiFaux,
          prompt: 'Il a plu ?', correctBool: true,
          answerers: const ['p3'], createdAt: DateTime(2026));
      expect(q.canAnswer('p2'), isFalse);
      expect(q.canAnswer('p3'), isTrue);
    });
  });

  test('formatNumber écrit les nombres à la française', () {
    expect(formatNumber(12), '12');
    expect(formatNumber(3.5), '3,5');
  });

  test("mode démo : la boîte reste scellée tant que le quiz n'est pas lancé", () async {
    // SharedPreferences « en mémoire » : pas besoin de vrai téléphone.
    SharedPreferences.setMockInitialValues({});
    final repo = DemoRepository(await DeviceState.load());

    final trip = await repo.createTrip(
        title: 'Étretat', emoji: '🏖️', profiles: const [papa, gaby, tom]);
    await repo.addQuestion(
        trip.code,
        Question(
            id: 'q1', authorId: 'p1', type: QuestionType.estimation,
            prompt: 'Combien de glaces ?', correctNumber: 14, unit: 'glaces',
            createdAt: DateTime(2026)),
        null);

    // Boîte scellée : aucune question lisible, mais le compteur est à jour.
    expect(await repo.loadQuestions(trip.code), isEmpty);
    final sealed = await repo.watchTrip(trip.code).first;
    expect(sealed!.questionCount, 1);
    expect(sealed.countByAuthor['p1'], 1);

    // Boîte ouverte : la question devient lisible.
    await repo.startQuiz(trip.code);
    final qs = await repo.loadQuestions(trip.code);
    expect(qs.single.correctLabel(sealed), '14 glaces');
  });
}

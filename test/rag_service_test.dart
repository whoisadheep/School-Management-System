import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_system/services/rag_service.dart';
import 'package:school_management_system/providers/navigation_provider.dart';

void main() {
  group('Advanced RAG Engine Tests', () {
    late RagService rag;

    setUp(() {
      rag = RagService();
    });

    test('Query Controller Intent Classification', () {
      // Greetings
      expect(rag.classifyIntent('hi there'), AssistantIntent.greeting);
      expect(rag.classifyIntent('hello eduvia'), AssistantIntent.greeting);
      expect(rag.classifyIntent('good morning'), AssistantIntent.greeting);

      // Direct Navigation
      expect(rag.classifyIntent('open fee collection'), AssistantIntent.navigation);
      expect(rag.classifyIntent('go to exam marks'), AssistantIntent.navigation);
      expect(rag.classifyIntent('take me to class setup'), AssistantIntent.navigation);

      // Knowledge / How-To
      expect(rag.classifyIntent('how do I assign subjects to class 1?'), AssistantIntent.knowledgeHowTo);
      expect(rag.classifyIntent('can Eduvia connect to biometric fingerprint?'), AssistantIntent.knowledgeHowTo);
      expect(rag.classifyIntent('where can I print report cards?'), AssistantIntent.knowledgeHowTo);
      expect(rag.classifyIntent('how to install vc redist msvcp140?'), AssistantIntent.knowledgeHowTo);

      // Database / Metrics Queries
      expect(rag.classifyIntent('how many students are in class 10?'), AssistantIntent.databaseQuery);
      expect(rag.classifyIntent('total count of teachers'), AssistantIntent.databaseQuery);
      expect(rag.classifyIntent('how much fee is collected today?'), AssistantIntent.databaseQuery);
    });

    test('Query Transformation and Terminology Expansion', () {
      // Subject expansion
      final transformedSubjects = rag.transformQuery('how to add subjects to class 1?');
      expect(transformedSubjects.contains('curriculum') || transformedSubjects.contains('classes'), isTrue);

      // Marks rooster misspelling / synonym expansion
      final transformedRoster = rag.transformQuery('where is marks rooster?');
      expect(transformedRoster.contains('examinations') || transformedRoster.contains('roster'), isTrue);

      // Biometric / unsupported expansion
      final transformedBiometric = rag.transformQuery('can I use biometric scanner?');
      expect(transformedBiometric.contains('capabilities') || transformedBiometric.contains('limitations'), isTrue);
    });

    test('Navigation Tab Target Resolution', () {
      expect(rag.resolveTargetTab('how to collect fees?'), NavigationTab.feeCollection);
      expect(rag.resolveTargetTab('where do I setup class subjects?'), NavigationTab.classes);
      expect(rag.resolveTargetTab('where do I enter marks for exam?'), NavigationTab.exams);
      expect(rag.resolveTargetTab('how to admit new student?'), NavigationTab.admission);
      expect(rag.resolveTargetTab('how to generate salary slip?'), NavigationTab.staff);
      expect(rag.resolveTargetTab('where is bus transport route?'), NavigationTab.transport);
      expect(rag.resolveTargetTab('where to backup database?'), NavigationTab.settings);
    });
  });
}

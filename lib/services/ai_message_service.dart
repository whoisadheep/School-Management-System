import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

final aiMessageServiceProvider = Provider((ref) => AiMessageService());

class AiMessageService {
  final Dio _http = Dio();

  AiMessageService();

  Future<String> generateOverdueReminder({
    required String studentName,
    required String amountStr,
    required String grade,
  }) async {
    try {
      final prompt = '''You are the administration of a school. Write a short, polite, and professional WhatsApp reminder message to the parents of "$studentName" (who is in "$grade"). They have an overdue fee balance of $amountStr. The tone should be gentle but firm, requesting them to clear the dues at their earliest convenience to avoid any disruption. Do not use placeholders like [School Name], just write it generically from "School Administration". Keep it under 3-4 sentences.''';

      final proxy = dotenv.env['ASSISTANT_PROXY_URL'] ?? 'http://localhost:3000';
      final installationKey = dotenv.env['ASSISTANT_INSTALLATION_KEY'] ?? '';

      final resp = await _http.post('$proxy/assistant/query', data: {
        'schema': '',
        'userQuestion': prompt,
        'conversationHistory': [],
        'installationKey': installationKey,
      });

      if (resp.statusCode == 200) {
        final data = resp.data as Map<String, dynamic>;
        if (data['final'] == true) {
          return (data['text'] as String?)?.trim() ?? _fallbackMessage(studentName, amountStr);
        }
      }

      return _fallbackMessage(studentName, amountStr);
    } catch (e) {
      return _fallbackMessage(studentName, amountStr);
    }
  }

  String _fallbackMessage(String studentName, String amountStr) {
    return 'Dear Parent, this is a gentle reminder from the School Administration that fee dues of $amountStr for your child $studentName are currently overdue. Kindly clear the pending dues at your earliest convenience. Thank you.';
  }
}

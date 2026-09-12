import 'dart:convert';
import 'ai_provider_service.dart';
import 'database_service.dart';

/// Defines the Eduvia fields that imported data can map to.
class EduviaField {
  final String key;
  final String label;
  final bool isRequired;

  const EduviaField({required this.key, required this.label, this.isRequired = false});

  static const List<EduviaField> studentFields = [
    EduviaField(key: 'skip', label: '⏭ Skip / Ignore'),
    EduviaField(key: 'admission_number', label: 'Admission Number'),
    EduviaField(key: 'first_name', label: 'First Name', isRequired: true),
    EduviaField(key: 'last_name', label: 'Last Name'),
    EduviaField(key: 'full_name', label: 'Full Name (auto-split)'),
    EduviaField(key: 'roll_number', label: 'Roll Number'),
    EduviaField(key: 'class', label: 'Class / Grade', isRequired: true),
    EduviaField(key: 'section', label: 'Section'),
    EduviaField(key: 'dob', label: 'Date of Birth'),
    EduviaField(key: 'gender', label: 'Gender'),
    EduviaField(key: 'blood_group', label: 'Blood Group'),
    EduviaField(key: 'religion', label: 'Religion'),
    EduviaField(key: 'caste', label: 'Category / Caste'),
    EduviaField(key: 'aadhaar', label: 'Aadhaar Number'),
    EduviaField(key: 'admission_date', label: 'Admission Date'),
    EduviaField(key: 'father_name', label: 'Father Name'),
    EduviaField(key: 'father_phone', label: 'Father Phone'),
    EduviaField(key: 'mother_name', label: 'Mother Name'),
    EduviaField(key: 'mother_phone', label: 'Mother Phone'),
    EduviaField(key: 'guardian_phone', label: 'Primary Contact / Guardian Phone'),
    EduviaField(key: 'residential_address', label: 'Current / Residential Address'),
    EduviaField(key: 'permanent_address', label: 'Permanent Address'),
  ];
}

/// Represents a single column mapping: source header → Eduvia field key.
class ColumnMapping {
  final String sourceHeader;
  String eduviaFieldKey;
  final double confidence;

  ColumnMapping({
    required this.sourceHeader,
    required this.eduviaFieldKey,
    this.confidence = 0.0,
  });
}

/// Result of column mapping, including metadata on which provider answered.
class ColumnMappingResponse {
  final List<ColumnMapping> mappings;
  final String providerName; // 'OpenRouter', 'Groq', 'Gemini', 'Local Rules'
  final String? model;

  const ColumnMappingResponse({
    required this.mappings,
    required this.providerName,
    this.model,
  });
}

/// Service that uses the strict cascade:
/// 1. OpenRouter (Llama 3.3 70B)
/// 2. Groq (Qwen 3.8 27B)
/// 3. Gemini (Gemini Flash)
/// 4. Local Rule-Based Engine
/// Only headers are sent to remote providers — ZERO student data.
class ColumnMappingService {
  final DatabaseService _dbService;
  late final AiProviderService _aiProvider;

  ColumnMappingService(this._dbService) {
    _aiProvider = AiProviderService(_dbService);
  }

  /// Maps columns using the strict 4-stage cascade.
  Future<ColumnMappingResponse> mapColumnsWithAI(List<String> sourceHeaders) async {
    final eduviaFieldsList = EduviaField.studentFields
        .where((f) => f.key != 'skip')
        .map((f) => '  "${f.key}": "${f.label}"')
        .join(',\n');

    final prompt = '''Map each header to the most appropriate Eduvia student database field:
Headers:
${sourceHeaders.map((h) => '  - "$h"').join('\n')}

Eduvia fields list:
{
$eduviaFieldsList
}

If a column does not match any field, map it to "skip".

IMPORTANT: Respond with ONLY a valid JSON array, no commentary, no markdown. Example:
[{"source":"Student Name","target":"full_name","confidence":0.95},{"source":"Enrollment ID","target":"admission_number","confidence":0.9}]''';

    const systemInstruction =
        'You are an expert data engineer and column mapping AI. Return ONLY a valid JSON array mapping spreadsheet columns to database fields.';

    // Execute cascade: OpenRouter -> Groq -> Gemini
    try {
      final aiResult = await _aiProvider.generateText(
        prompt: prompt,
        systemInstruction: systemInstruction,
        temperature: 0.1,
        maxTokens: 1500,
      );

      if (aiResult != null && aiResult.text.isNotEmpty) {
        final mappings = _parseAiMappings(aiResult.text, sourceHeaders);
        if (mappings != null && mappings.isNotEmpty) {
          return ColumnMappingResponse(
            mappings: mappings,
            providerName: aiResult.provider,
            model: aiResult.model,
          );
        }
      }
    } catch (_) {
      // Fall through to local fallback
    }

    // Stage 4: Local Rule-Based Engine (Offline)
    final localMappings = _ruleBasedMapping(sourceHeaders);
    return ColumnMappingResponse(
      mappings: localMappings,
      providerName: 'Local Rules (Offline)',
      model: 'Rule-based Regex Engine',
    );
  }

  List<ColumnMapping>? _parseAiMappings(String rawText, List<String> sourceHeaders) {
    try {
      var text = rawText.trim();
      text = text.replaceAll(RegExp(r'```json\s*'), '').replaceAll(RegExp(r'```\s*'), '').trim();

      // Find JSON array bounds if extra text was included
      final start = text.indexOf('[');
      final end = text.lastIndexOf(']');
      if (start >= 0 && end > start) {
        text = text.substring(start, end + 1);
      }

      final parsed = jsonDecode(text) as List;
      final mappings = <ColumnMapping>[];
      final validKeys = EduviaField.studentFields.map((f) => f.key).toSet();

      for (final item in parsed) {
        final source = item['source']?.toString() ?? '';
        var target = item['target']?.toString() ?? 'skip';
        final confidence = (item['confidence'] as num?)?.toDouble() ?? 0.85;

        if (!validKeys.contains(target)) target = 'skip';

        if (source.isNotEmpty) {
          mappings.add(ColumnMapping(
            sourceHeader: source,
            eduviaFieldKey: target,
            confidence: confidence,
          ));
        }
      }

      // Fill in any headers the AI may have omitted
      for (final header in sourceHeaders) {
        if (!mappings.any((m) => m.sourceHeader.toLowerCase() == header.toLowerCase())) {
          mappings.add(ColumnMapping(
            sourceHeader: header,
            eduviaFieldKey: 'skip',
            confidence: 0.0,
          ));
        }
      }

      return mappings;
    } catch (_) {
      return null;
    }
  }

  /// Fallback rule-based column mapping using common school database patterns.
  List<ColumnMapping> _ruleBasedMapping(List<String> headers) {
    final mappings = <ColumnMapping>[];

    for (final header in headers) {
      final lower = header.toLowerCase().replaceAll(RegExp(r'[_\-\s]+'), ' ').trim();
      String key = 'skip';
      double confidence = 0.0;

      if (_matches(lower, ['admission number', 'admission no', 'adm no', 'enrollment', 'enrol', 'adm code', 'sr no', 'serial', 'reg no', 'registration no'])) {
        key = 'admission_number'; confidence = 0.9;
      } else if (_matches(lower, ['first name', 'firstname', 'f name', 'fname', 'given name'])) {
        key = 'first_name'; confidence = 0.95;
      } else if (_matches(lower, ['last name', 'lastname', 'l name', 'lname', 'surname', 'family name'])) {
        key = 'last_name'; confidence = 0.95;
      } else if (_matches(lower, ['student name', 'full name', 'name', 'pupil', 'candidate name'])) {
        key = 'full_name'; confidence = 0.85;
      } else if (_matches(lower, ['roll', 'roll no', 'roll number'])) {
        key = 'roll_number'; confidence = 0.9;
      } else if (_matches(lower, ['class', 'grade', 'standard', 'std', 'grade level'])) {
        key = 'class'; confidence = 0.9;
      } else if (_matches(lower, ['section', 'sec', 'division', 'div'])) {
        key = 'section'; confidence = 0.9;
      } else if (_matches(lower, ['dob', 'date of birth', 'birth date', 'birthday'])) {
        key = 'dob'; confidence = 0.9;
      } else if (_matches(lower, ['gender', 'sex'])) {
        key = 'gender'; confidence = 0.95;
      } else if (_matches(lower, ['blood', 'blood group'])) {
        key = 'blood_group'; confidence = 0.9;
      } else if (_matches(lower, ['religion'])) {
        key = 'religion'; confidence = 0.9;
      } else if (_matches(lower, ['caste', 'category', 'cat', 'community'])) {
        key = 'caste'; confidence = 0.85;
      } else if (_matches(lower, ['aadhaar', 'aadhar', 'uid', 'aadhaar number', 'uidai'])) {
        key = 'aadhaar'; confidence = 0.9;
      } else if (_matches(lower, ['admission date', 'date of admission', 'enrolled date', 'doa'])) {
        key = 'admission_date'; confidence = 0.85;
      } else if (_matches(lower, ['father name', 'father', 'dad name', 'father s name', 's/o', 'd/o'])) {
        key = 'father_name'; confidence = 0.85;
      } else if (_matches(lower, ['father phone', 'father mobile', 'father cell', 'father contact'])) {
        key = 'father_phone'; confidence = 0.85;
      } else if (_matches(lower, ['mother name', 'mother', 'mom name', 'mother s name'])) {
        key = 'mother_name'; confidence = 0.85;
      } else if (_matches(lower, ['mother phone', 'mother mobile', 'mother cell', 'mother contact'])) {
        key = 'mother_phone'; confidence = 0.85;
      } else if (_matches(lower, ['phone', 'mobile', 'contact', 'guardian phone', 'contact number', 'cell', 'whatsapp'])) {
        key = 'guardian_phone'; confidence = 0.75;
      } else if (_matches(lower, ['address', 'current address', 'residential', 'home address', 'residence'])) {
        key = 'residential_address'; confidence = 0.8;
      } else if (_matches(lower, ['permanent address', 'perm address'])) {
        key = 'permanent_address'; confidence = 0.85;
      }

      mappings.add(ColumnMapping(sourceHeader: header, eduviaFieldKey: key, confidence: confidence));
    }

    return mappings;
  }

  bool _matches(String input, List<String> patterns) {
    for (final p in patterns) {
      if (input == p || input.contains(p)) return true;
    }
    return false;
  }
}

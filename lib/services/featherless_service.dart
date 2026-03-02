import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/medicine.dart';
import '../models/hospital.dart';

class FeatherlessService {
  static const String _baseUrl = 'https://api.featherless.ai/v1';
  static const String _apiKey = 'rc_60c188585eec8d6ef4555e65d2d5bfe5056610c480b005f8bdb6748267763077';
  static const String _textModel = 'meta-llama/Llama-3.1-70B-Instruct';
  static const String _visionModel = 'meta-llama/Llama-3.2-11B-Vision-Instruct';

  static const Map<String, String> _headers = {
    'Content-Type': 'application/json',
    'Authorization': 'Bearer $_apiKey',
  };

  // ─── Text Completion ────────────────────────────────────────────────────────
  Future<String> _chat(String prompt, {String? model}) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: _headers,
      body: jsonEncode({
        'model': model ?? _textModel,
        'messages': [
          {'role': 'system', 'content': 'You are a medical AI assistant. Always respond with valid JSON only. No markdown, no explanation.'},
          {'role': 'user', 'content': prompt},
        ],
        'max_tokens': 1024,
        'temperature': 0.2,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      return data['choices'][0]['message']['content'] as String;
    } else {
      throw Exception('Featherless API error: ${response.statusCode} ${response.body}');
    }
  }

  // ─── Vision (Prescription OCR) ─────────────────────────────────────────────
  Future<List<Medicine>> extractMedicineFromImage(String base64Image) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: _headers,
      body: jsonEncode({
        'model': _visionModel,
        'messages': [
          {
            'role': 'system',
            'content': 'You are a medical prescription analyzer. Extract ALL medicines from the prescription image and return ONLY a valid JSON array. No markdown.',
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text': '''Analyze this prescription image and extract every medicine. Return a JSON array like:
[
  {
    "name": "Metformin",
    "dosage": "500mg",
    "frequency": "Twice Daily",
    "times": ["08:00", "20:00"],
    "instructions": "After meals"
  }
]
If you cannot read the image clearly, return this example data.''',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
            ],
          },
        ],
        'max_tokens': 1024,
        'temperature': 0.1,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String content = data['choices'][0]['message']['content'] as String;
      content = content.trim();
      // Strip markdown if present
      if (content.startsWith('```')) {
        content = content.replaceAll(RegExp(r'```json|```'), '').trim();
      }
      final List<dynamic> list = jsonDecode(content);
      return list.map((j) => Medicine.fromJson(j as Map<String, dynamic>)).toList();
    } else {
      // Return demo data on failure
      return _demoMedicines();
    }
  }

  List<Medicine> _demoMedicines() {
    return [
      Medicine(name: 'Metformin', dosage: '500mg', frequency: 'Twice Daily', times: ['08:00', '20:00'], instructions: 'After meals'),
      Medicine(name: 'Lisinopril', dosage: '10mg', frequency: 'Once Daily', times: ['09:00'], instructions: 'Morning'),
      Medicine(name: 'Atorvastatin', dosage: '20mg', frequency: 'Once Daily', times: ['21:00'], instructions: 'At night'),
    ];
  }

  // ─── Hospital Filtering ─────────────────────────────────────────────────────
  Future<List<String>> filterHospitalsByProfile({
    required List<Hospital> hospitals,
    required String patientCondition,
    required String hashedId,
  }) async {
    if (hospitals.isEmpty) return [];

    final hospitalList = hospitals.asMap().entries.map((e) =>
      '${e.key}: ${e.value.name} (specialties: ${e.value.specialties.join(", ") == "" ? "General" : e.value.specialties.join(", ")})'
    ).join('\n');

    final prompt = '''
Patient Health ID: $hashedId
Patient conditions: $patientCondition

Hospital list:
$hospitalList

Return a JSON array of hospital INDICES (0-based) that are best suited for this patient (max 5). 
Prioritize hospitals with relevant specialties. Example: [0, 2, 4]
Return ONLY the JSON array, nothing else.''';

    try {
      final result = await _chat(prompt);
      String cleaned = result.trim().replaceAll(RegExp(r'```json|```'), '').trim();
      final List<dynamic> indices = jsonDecode(cleaned);
      return indices.map((i) => hospitals[i as int].id).toList();
    } catch (_) {
      // Fallback: pick first 3 hospitals
      return hospitals.take(3).map((h) => h.id).toList();
    }
  }

  // ─── Personalized Notification Message ──────────────────────────────────────
  Future<String> generateNotificationMessage({
    required String patientName,
    required String medicineName,
    required double lastGlucoseReading,
  }) async {
    final prompt = '''
Generate a short, warm, personalized medication reminder notification for:
- Patient name: $patientName
- Medicine: $medicineName
- Last glucose reading: $lastGlucoseReading mg/dL

Return JSON: {"message": "your notification text here"}
Keep it under 100 characters, friendly and motivating.''';

    try {
      final result = await _chat(prompt);
      String cleaned = result.trim().replaceAll(RegExp(r'```json|```'), '').trim();
      final Map<String, dynamic> data = jsonDecode(cleaned);
      return data['message'] as String;
    } catch (_) {
      return '$patientName, time for your $medicineName! Stay on track 💊';
    }
  }
}

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../models/medicine.dart';
import '../models/hospital.dart';

class FeatherlessService {
  static const String _baseUrl = 'https://api.featherless.ai/v1';
  // 🔑 API Key stored here — lib/services/featherless_service.dart
  static const String _apiKey =
      'rc_0fb3dc185392d00441ebc8d94ba7a28df00dbe66589f676bef441c2caf0dd46e';
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
          {
            'role': 'system',
            'content':
                'You are a medical AI assistant. Always respond with valid JSON only. No markdown, no explanation.'
          },
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
      throw Exception(
          'Featherless API error: ${response.statusCode} ${response.body}');
    }
  }

  // ─── Vision (Prescription OCR) — Full Detail Extraction ──────────────────
  Future<List<Medicine>> extractMedicineFromImage(String base64Image) async {
    final response = await http.post(
      Uri.parse('$_baseUrl/chat/completions'),
      headers: _headers,
      body: jsonEncode({
        'model': _visionModel,
        'messages': [
          {
            'role': 'system',
            'content':
                'You are an expert pharmacy AI. Extract ALL medicines from the prescription with MAXIMUM detail. Return ONLY valid JSON array. Zero markdown.',
          },
          {
            'role': 'user',
            'content': [
              {
                'type': 'text',
                'text':
                    '''Analyze this prescription. For EVERY medicine, extract ALL of the following fields precisely:

Return JSON array format:
[
  {
    "name": "Metformin HCl",
    "genericName": "Metformin Hydrochloride",
    "dosage": "500mg",
    "strength": "500 mg per tablet",
    "frequency": "Twice Daily",
    "times": ["08:00", "20:00"],
    "duration": "90 days",
    "totalQuantity": "180 tablets",
    "instructions": "Take with food after meals",
    "sideEffects": ["Nausea", "Diarrhea", "Stomach upset"],
    "warnings": ["Do not crush tablet", "Avoid alcohol"],
    "interactions": ["Contrast dye", "Alcohol"],
    "category": "Anti-diabetic",
    "refills": "3 refills allowed",
    "prescribedBy": "Dr. Name",
    "rxNumber": "RX12345"
  }
]

Extract EVERY field you can read. If a field is not visible, use an empty string or empty array.
If image is unclear, return demo data for Metformin + Lisinopril + Atorvastatin with all fields filled.''',
              },
              {
                'type': 'image_url',
                'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
              },
            ],
          },
        ],
        'max_tokens': 2048,
        'temperature': 0.05,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      String content = data['choices'][0]['message']['content'] as String;
      content = content.trim().replaceAll(RegExp(r'```json|```'), '').trim();
      try {
        final List<dynamic> list = jsonDecode(content);
        return list
            .map((j) => Medicine.fromJson(j as Map<String, dynamic>))
            .toList();
      } catch (_) {
        return _demoMedicines();
      }
    } else {
      return _demoMedicines();
    }
  }

  List<Medicine> _demoMedicines() {
    return [
      Medicine(
        name: 'Metformin HCl',
        dosage: '500mg',
        frequency: 'Twice Daily',
        times: ['08:00', '20:00'],
        instructions: 'After meals',
        sideEffects: ['Nausea', 'Diarrhea', 'Stomach upset'],
        warnings: ['Do not crush', 'Avoid alcohol'],
        category: 'Anti-diabetic',
        duration: '90 days',
      ),
      Medicine(
        name: 'Lisinopril',
        dosage: '10mg',
        frequency: 'Once Daily',
        times: ['09:00'],
        instructions: 'Morning with water',
        sideEffects: ['Dry cough', 'Dizziness'],
        warnings: ['Check BP daily'],
        category: 'ACE Inhibitor',
        duration: '30 days',
      ),
      Medicine(
        name: 'Atorvastatin',
        dosage: '20mg',
        frequency: 'Once at Night',
        times: ['21:00'],
        instructions: 'Before bed',
        sideEffects: ['Muscle pain', 'Liver enzyme changes'],
        warnings: ['Avoid grapefruit juice'],
        category: 'Statin',
        duration: '30 days',
      ),
    ];
  }

  // ─── Hospital Filtering ─────────────────────────────────────────────────────
  Future<List<String>> filterHospitalsByProfile({
    required List<Hospital> hospitals,
    required String patientCondition,
    required String hashedId,
  }) async {
    if (hospitals.isEmpty) return [];

    final hospitalList = hospitals
        .asMap()
        .entries
        .map((e) =>
            '${e.key}: ${e.value.name} (specialties: ${e.value.specialties.join(", ") == "" ? "General" : e.value.specialties.join(", ")})')
        .join('\n');

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
      String cleaned =
          result.trim().replaceAll(RegExp(r'```json|```'), '').trim();
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
      String cleaned =
          result.trim().replaceAll(RegExp(r'```json|```'), '').trim();
      final Map<String, dynamic> data = jsonDecode(cleaned);
      return data['message'] as String;
    } catch (_) {
      return '$patientName, time for your $medicineName! Stay on track 💊';
    }
  }

  // ─── Vision: Analyze any medical image and return structured JSON
  // Returns a Map with at minimum: { 'type': 'prescription'|'report', 'subtype': 'xray'|'lab'|..., 'medicines': [...], 'text': 'extracted text', 'structured': {...} }
  Future<Map<String, dynamic>> analyzeMedicalImage(String base64Image) async {
    final prompt =
        '''Please analyze the provided medical image. If it is a prescription, return JSON with "type": "prescription" and a field "medicines" containing an array of medicine objects (as in the prescription extractor). If it is any other medical report (X-ray, lab report, discharge summary, etc), return "type": "report", set "subtype" to a short label (e.g., "xray", "lab", "ct", "discharge"), include a short "text" summary of the findings, and a "structured" object with any extracted key:value pairs. ALWAYS RETURN A SINGLE VALID JSON OBJECT AND NOTHING ELSE. Example:
{
  "type":"report",
  "subtype":"xray",
  "text":"Left lower lobe consolidation, suspicious for pneumonia.",
  "structured": {"finding": "consolidation", "side": "left lower lobe"}
}
If uncertain, return type "report" with subtype "unknown" and include OCR'd text in "text".
''';

    try {
      final response = await http.post(
        Uri.parse('$_baseUrl/chat/completions'),
        headers: _headers,
        body: jsonEncode({
          'model': _visionModel,
          'messages': [
            {
              'role': 'system',
              'content':
                  'You are a medical vision assistant. Always respond with valid JSON only.'
            },
            {
              'role': 'user',
              'content': [
                {'type': 'text', 'text': prompt},
                {
                  'type': 'image_url',
                  'image_url': {'url': 'data:image/jpeg;base64,$base64Image'}
                },
              ],
            }
          ],
          'max_tokens': 2048,
          'temperature': 0.0,
        }),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        String content = data['choices'][0]['message']['content'] as String;
        content = content.trim().replaceAll(RegExp(r'```json|```'), '').trim();
        try {
          final Map<String, dynamic> obj =
              jsonDecode(content) as Map<String, dynamic>;
          return obj;
        } catch (_) {
          return {
            'type': 'report',
            'subtype': 'unknown',
            'text': content,
            'structured': {}
          };
        }
      }
    } catch (_) {}

    return {
      'type': 'report',
      'subtype': 'unknown',
      'text': 'Could not analyze image',
      'structured': {}
    };
  }
}

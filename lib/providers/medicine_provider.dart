import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medicine.dart';
import '../services/featherless_service.dart';
import '../services/mongo_report_service.dart';
import '../services/notification_service.dart';
import '../models/health_profile.dart';
import 'health_profile_provider.dart';

final featherlessServiceProvider = Provider((ref) => FeatherlessService());
final notificationServiceProvider = Provider((ref) => NotificationService());

// Medicine state
class MedicineNotifier extends AsyncNotifier<List<Medicine>> {
  @override
  Future<List<Medicine>> build() async => [];

  Future<Map<String, dynamic>> scanPrescription(String base64Image) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(featherlessServiceProvider);
      // First analyze the image to determine if it's a prescription or other report
      final analysis = await service.analyzeMedicalImage(base64Image);
      final String type = (analysis['type'] as String?) ?? 'report';

      if (type == 'prescription') {
        // If the analyzer returned medicine details, use them; otherwise fall back to OCR extractor
        if (analysis['medicines'] != null && analysis['medicines'] is List) {
          final meds = (analysis['medicines'] as List)
              .map((e) => Medicine.fromJson(e as Map<String, dynamic>))
              .toList();
          state = AsyncValue.data(meds);
        } else {
          final medicines = await service.extractMedicineFromImage(base64Image);
          state = AsyncValue.data(medicines);
        }
        return {
          'type': 'prescription',
          'count': state.valueOrNull?.length ?? 0
        };
      } else {
        // Non-prescription medical report: persist to local MongoDB as JSON
        final db = MongoReportService();
        await db.init();
        await db.insertReport(
          type: 'report',
          subtype: (analysis['subtype'] as String?) ?? 'unknown',
          content: Map<String, dynamic>.from(analysis),
        );
        // Return empty medicine list for UI; report viewer should read from MongoDB
        state = const AsyncValue.data([]);
        return {
          'type': 'report',
          'subtype': (analysis['subtype'] as String?) ?? 'unknown',
          'saved': true
        };
      }
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return {'type': 'error', 'message': e.toString()};
    }
  }

  Future<void> scheduleAllReminders() async {
    final medicines = state.valueOrNull ?? [];
    final notificationSvc = ref.read(notificationServiceProvider);
    await notificationSvc.scheduleAllMedicines(
      medicines: medicines,
      patientName: ref.read(healthProfileProvider).name,
      lastGlucose: ref.read(healthProfileProvider).lastGlucoseReading,
    );
    // Mark all as scheduled
    state = AsyncValue.data(
      medicines
          .map((m) => Medicine(
                name: m.name,
                dosage: m.dosage,
                frequency: m.frequency,
                times: m.times,
                instructions: m.instructions,
                reminderSet: true,
              ))
          .toList(),
    );
  }

  void loadDemo() {
    state = AsyncValue.data([
      Medicine(
          name: 'Metformin',
          dosage: '500mg',
          frequency: 'Twice Daily',
          times: ['08:00', '20:00'],
          instructions: 'After meals'),
      Medicine(
          name: 'Lisinopril',
          dosage: '10mg',
          frequency: 'Once Daily',
          times: ['09:00'],
          instructions: 'Morning'),
      Medicine(
          name: 'Atorvastatin',
          dosage: '20mg',
          frequency: 'Once Daily',
          times: ['21:00'],
          instructions: 'At night'),
    ]);
  }
}

final medicineProvider =
    AsyncNotifierProvider<MedicineNotifier, List<Medicine>>(
        MedicineNotifier.new);

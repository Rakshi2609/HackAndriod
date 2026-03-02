import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/medicine.dart';
import '../services/featherless_service.dart';
import '../services/notification_service.dart';
import '../models/health_profile.dart';

final featherlessServiceProvider = Provider((ref) => FeatherlessService());
final notificationServiceProvider = Provider((ref) => NotificationService());

// Medicine state
class MedicineNotifier extends AsyncNotifier<List<Medicine>> {
  @override
  Future<List<Medicine>> build() async => [];

  Future<void> scanPrescription(String base64Image) async {
    state = const AsyncValue.loading();
    try {
      final service = ref.read(featherlessServiceProvider);
      final medicines = await service.extractMedicineFromImage(base64Image);
      state = AsyncValue.data(medicines);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> scheduleAllReminders() async {
    final medicines = state.valueOrNull ?? [];
    final notificationSvc = ref.read(notificationServiceProvider);
    await notificationSvc.scheduleAllMedicines(
      medicines: medicines,
      patientName: HealthProfile.sara.name,
      lastGlucose: HealthProfile.sara.lastGlucoseReading,
    );
    // Mark all as scheduled
    state = AsyncValue.data(
      medicines.map((m) => Medicine(
        name: m.name, dosage: m.dosage, frequency: m.frequency,
        times: m.times, instructions: m.instructions, reminderSet: true,
      )).toList(),
    );
  }

  void loadDemo() {
    state = AsyncValue.data([
      Medicine(name: 'Metformin', dosage: '500mg', frequency: 'Twice Daily', times: ['08:00', '20:00'], instructions: 'After meals'),
      Medicine(name: 'Lisinopril', dosage: '10mg', frequency: 'Once Daily', times: ['09:00'], instructions: 'Morning'),
      Medicine(name: 'Atorvastatin', dosage: '20mg', frequency: 'Once Daily', times: ['21:00'], instructions: 'At night'),
    ]);
  }
}

final medicineProvider = AsyncNotifierProvider<MedicineNotifier, List<Medicine>>(MedicineNotifier.new);

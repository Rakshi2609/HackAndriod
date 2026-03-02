import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_profile.dart';

// Holds digital prescription pushed by doctor
final digitalPrescriptionProvider = StateProvider<String?>((ref) => null);

// Active health profile
final healthProfileProvider = Provider<HealthProfile>((ref) => HealthProfile.sara);

// View mode toggle (patient vs doctor)
final doctorModeProvider = StateProvider<bool>((ref) => false);

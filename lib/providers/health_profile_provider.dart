import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/health_profile.dart';

// Holds digital prescription pushed by doctor
final digitalPrescriptionProvider = StateProvider<String?>((ref) => null);

// Active health profile (mutable so we can set logged-in user)
final healthProfileProvider =
    StateProvider<HealthProfile>((ref) => HealthProfile.sara);

// View mode toggle (patient vs doctor)
final doctorModeProvider = StateProvider<bool>((ref) => false);

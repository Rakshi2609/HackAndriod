class HealthProfile {
  final String name;
  final String email;
  final String phone;
  final String bloodGroup;
  final List<String> conditions;
  final List<String> allergies;
  final String hashedId;
  final double lastGlucoseReading;

  const HealthProfile({
    required this.name,
    required this.email,
    required this.phone,
    required this.bloodGroup,
    required this.conditions,
    required this.allergies,
    required this.hashedId,
    this.lastGlucoseReading = 126.0,
  });

  static const HealthProfile sara = HealthProfile(
    name: 'Sara Miller',
    email: 'sara@antigravity.health',
    phone: '+91-9876543210',
    bloodGroup: 'O+',
    conditions: ['Type 2 Diabetes', 'Hypertension'],
    allergies: ['Penicillin'],
    hashedId: 'AG-F3A21B99',
    lastGlucoseReading: 134.0,
  );
}

class Medicine {
  final String name;
  final String dosage;
  final String frequency;
  final List<String> times; // e.g. ["08:00", "20:00"]
  final String instructions; // e.g. "After meals"
  bool reminderSet;

  Medicine({
    required this.name,
    required this.dosage,
    required this.frequency,
    required this.times,
    this.instructions = '',
    this.reminderSet = false,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    List<String> times = [];
    if (json['times'] != null) {
      times = List<String>.from(json['times']);
    } else {
      // Auto-generate times from frequency
      final freq = (json['frequency'] ?? '').toLowerCase();
      if (freq.contains('twice') || freq.contains('2')) {
        times = ['08:00', '20:00'];
      } else if (freq.contains('three') || freq.contains('3')) {
        times = ['08:00', '14:00', '20:00'];
      } else {
        times = ['09:00'];
      }
    }
    return Medicine(
      name: json['name'] ?? 'Unknown',
      dosage: json['dosage'] ?? '',
      frequency: json['frequency'] ?? '',
      times: times,
      instructions: json['instructions'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'dosage': dosage,
    'frequency': frequency,
    'times': times,
    'instructions': instructions,
  };
}

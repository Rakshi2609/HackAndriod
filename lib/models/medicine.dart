class Medicine {
  final String name;
  final String genericName;
  final String dosage;
  final String strength;
  final String frequency;
  final List<String> times;
  final String instructions;
  final String duration;
  final String totalQuantity;
  final List<String> sideEffects;
  final List<String> warnings;
  final List<String> interactions;
  final String category;
  final String refills;
  final String prescribedBy;
  final String rxNumber;
  bool reminderSet;

  Medicine({
    required this.name,
    this.genericName = '',
    required this.dosage,
    this.strength = '',
    required this.frequency,
    required this.times,
    this.instructions = '',
    this.duration = '',
    this.totalQuantity = '',
    this.sideEffects = const [],
    this.warnings = const [],
    this.interactions = const [],
    this.category = '',
    this.refills = '',
    this.prescribedBy = '',
    this.rxNumber = '',
    this.reminderSet = false,
  });

  factory Medicine.fromJson(Map<String, dynamic> json) {
    List<String> times = [];
    if (json['times'] != null) {
      times = List<String>.from(json['times']);
    } else {
      final freq = (json['frequency'] ?? '').toLowerCase();
      if (freq.contains('twice') || freq.contains('2')) {
        times = ['08:00', '20:00'];
      } else if (freq.contains('three') || freq.contains('3')) {
        times = ['08:00', '14:00', '20:00'];
      } else {
        times = ['09:00'];
      }
    }

    List<String> _list(dynamic v) =>
        v == null ? [] : List<String>.from(v as List);

    return Medicine(
      name: json['name'] ?? 'Unknown',
      genericName: json['genericName'] ?? '',
      dosage: json['dosage'] ?? '',
      strength: json['strength'] ?? '',
      frequency: json['frequency'] ?? '',
      times: times,
      instructions: json['instructions'] ?? '',
      duration: json['duration'] ?? '',
      totalQuantity: json['totalQuantity'] ?? '',
      sideEffects: _list(json['sideEffects']),
      warnings: _list(json['warnings']),
      interactions: _list(json['interactions']),
      category: json['category'] ?? '',
      refills: json['refills'] ?? '',
      prescribedBy: json['prescribedBy'] ?? '',
      rxNumber: json['rxNumber'] ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'genericName': genericName,
    'dosage': dosage,
    'strength': strength,
    'frequency': frequency,
    'times': times,
    'instructions': instructions,
    'duration': duration,
    'totalQuantity': totalQuantity,
    'sideEffects': sideEffects,
    'warnings': warnings,
    'interactions': interactions,
    'category': category,
    'refills': refills,
    'prescribedBy': prescribedBy,
    'rxNumber': rxNumber,
  };
}

class Hospital {
  final String id;
  final String name;
  final double lat;
  final double lon;
  final String? phone;
  final String? address;
  bool isAiVerified;
  final List<String> specialties;
  final double? rating;

  Hospital({
    required this.id,
    required this.name,
    required this.lat,
    required this.lon,
    this.phone,
    this.address,
    this.isAiVerified = false,
    this.specialties = const [],
    this.rating,
  });

  factory Hospital.fromOverpass(Map<String, dynamic> element) {
    final tags = element['tags'] as Map<String, dynamic>? ?? {};
    return Hospital(
      id: element['id'].toString(),
      name: tags['name'] ?? tags['operator'] ?? 'Unnamed Clinic',
      lat: (element['lat'] as num).toDouble(),
      lon: (element['lon'] as num).toDouble(),
      phone: tags['phone'],
      address: _buildAddress(tags),
      specialties: _extractSpecialties(tags),
    );
  }

  static String? _buildAddress(Map<String, dynamic> tags) {
    final parts = [
      tags['addr:housenumber'],
      tags['addr:street'],
      tags['addr:city'],
    ].whereType<String>().toList();
    return parts.isEmpty ? null : parts.join(', ');
  }

  static List<String> _extractSpecialties(Map<String, dynamic> tags) {
    final List<String> specs = [];
    if (tags['healthcare:speciality'] != null) {
      specs.addAll((tags['healthcare:speciality'] as String).split(';'));
    }
    if (tags['amenity'] == 'hospital') specs.add('General');
    if (tags['amenity'] == 'clinic') specs.add('Clinic');
    return specs;
  }
}

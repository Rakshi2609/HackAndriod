import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import '../models/hospital.dart';

class LocationService {
  static const String _overpassUrl = 'https://overpass-api.de/api/interpreter';

  /// Fetch nearby hospitals/clinics from OpenStreetMap Overpass API
  Future<List<Hospital>> fetchNearbyHospitals({
    required double lat,
    required double lon,
    double radiusKm = 5.0,
  }) async {
    final radiusM = (radiusKm * 1000).toInt();

    final query = '''
[out:json][timeout:25];
(
  node["amenity"="hospital"](around:$radiusM,$lat,$lon);
  node["amenity"="clinic"](around:$radiusM,$lat,$lon);
  node["healthcare"="hospital"](around:$radiusM,$lat,$lon);
  node["healthcare"="clinic"](around:$radiusM,$lat,$lon);
);
out body;
''';

    try {
      final response = await http.post(
        Uri.parse(_overpassUrl),
        headers: {'Content-Type': 'application/x-www-form-urlencoded'},
        body: {'data': query},
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final elements = (data['elements'] as List<dynamic>);
        return elements
            .where((e) => e['lat'] != null && e['lon'] != null)
            .map((e) => Hospital.fromOverpass(e as Map<String, dynamic>))
            .toList();
      }
    } catch (_) {}

    // Fallback: mock hospitals around given coordinates
    return _mockHospitals(lat, lon);
  }

  List<Hospital> _mockHospitals(double lat, double lon) {
    return [
      Hospital(
          id: '1',
          name: 'Apollo Diabetes Care Centre',
          lat: lat + 0.01,
          lon: lon + 0.01,
          isAiVerified: true,
          specialties: ['Endocrinology', 'Diabetes'],
          rating: 4.8),
      Hospital(
          id: '2',
          name: 'City General Hospital',
          lat: lat - 0.01,
          lon: lon + 0.02,
          specialties: ['General', 'Emergency'],
          rating: 4.2),
      Hospital(
          id: '3',
          name: 'Fortis Heart & Vascular',
          lat: lat + 0.02,
          lon: lon - 0.01,
          specialties: ['Cardiology'],
          rating: 4.6),
      Hospital(
          id: '4',
          name: 'MedPlus Clinic',
          lat: lat - 0.02,
          lon: lon - 0.02,
          specialties: ['General'],
          rating: 3.9),
      Hospital(
          id: '5',
          name: 'Rajiv Endocrinology Institute',
          lat: lat + 0.015,
          lon: lon - 0.015,
          isAiVerified: true,
          specialties: ['Endocrinology', 'Thyroid'],
          rating: 4.9),
      Hospital(
          id: '6',
          name: 'Care Primary Health',
          lat: lat - 0.005,
          lon: lon + 0.03,
          specialties: ['Primary Care'],
          rating: 4.0),
      Hospital(
          id: '7',
          name: 'Nephrocare Centre',
          lat: lat + 0.03,
          lon: lon + 0.005,
          specialties: ['Nephrology'],
          rating: 4.4),
    ];
  }

  // Mock device location (Bengaluru, India)
  static const double mockLat = 12.9716;
  static const double mockLon = 77.5946;

  /// Get current device location with permissions; fall back to mock coords.
  Future<LatLng> getLocationLatLng() async {
    try {
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever) {
        return LatLng(mockLat, mockLon);
      }

      final pos = await Geolocator.getCurrentPosition(
          desiredAccuracy: LocationAccuracy.high);
      return LatLng(pos.latitude, pos.longitude);
    } catch (_) {
      return LatLng(mockLat, mockLon);
    }
  }
}

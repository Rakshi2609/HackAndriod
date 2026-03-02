import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/hospital.dart';
import '../services/featherless_service.dart';
import '../services/location_service.dart';
import '../models/health_profile.dart';
import 'package:latlong2/latlong.dart';

final featherlessProvider = Provider((ref) => FeatherlessService());
final locationServiceProvider = Provider((ref) => LocationService());

class HospitalNotifier extends AsyncNotifier<List<Hospital>> {
  @override
  Future<List<Hospital>> build() async {
    return _fetchAndFilter();
  }

  Future<List<Hospital>> _fetchAndFilter() async {
    final locationSvc = ref.read(locationServiceProvider);
    final featherless = ref.read(featherlessProvider);
    final deviceLoc = await locationSvc.getLocationLatLng();
    final hospitals = await locationSvc.fetchNearbyHospitals(
      lat: deviceLoc.latitude,
      lon: deviceLoc.longitude,
    );

    // Ask AI to pick the best ones
    final verifiedIds = await featherless.filterHospitalsByProfile(
      hospitals: hospitals,
      patientCondition: HealthProfile.sara.conditions.join(', '),
      hashedId: HealthProfile.sara.hashedId,
    );

    return hospitals
        .map((h) => Hospital(
              id: h.id,
              name: h.name,
              lat: h.lat,
              lon: h.lon,
              phone: h.phone,
              address: h.address,
              specialties: h.specialties,
              rating: h.rating,
              isAiVerified: verifiedIds.contains(h.id),
            ))
        .toList();
  }

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      state = AsyncValue.data(await _fetchAndFilter());
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final hospitalProvider =
    AsyncNotifierProvider<HospitalNotifier, List<Hospital>>(
        HospitalNotifier.new);

// Device location provider (returns current device LatLng or fallback)
final deviceLocationProvider = FutureProvider<LatLng>((ref) async {
  final locationSvc = ref.read(locationServiceProvider);
  return locationSvc.getLocationLatLng();
});

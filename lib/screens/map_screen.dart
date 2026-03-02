import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../providers/hospital_provider.dart';
import '../models/hospital.dart';
import '../services/location_service.dart';
import '../theme/app_theme.dart';

class MapScreen extends ConsumerWidget {
  const MapScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hospitalsAsync = ref.watch(hospitalProvider);

    return Scaffold(
      body: Stack(
        children: [
          hospitalsAsync.when(
            loading: () => _buildLoadingMap(),
            error: (e, _) => _buildMap([], context),
            data: (hospitals) => _buildMap(hospitals, context),
          ),
          // Header overlay
          Positioned(
            top: 0, left: 0, right: 0,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.deepNavy.withOpacity(0.9),
                    Colors.transparent,
                  ],
                ),
              ),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                bottom: 20, left: 20, right: 20,
              ),
              child: Row(
                children: [
                  const SizedBox(
                    width: 36, height: 36,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.local_hospital_rounded, color: Colors.white, size: 20),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nearby Hospitals', style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.white)),
                      Text('AI-curated for Sara\'s profile', style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.white60, fontSize: 11)),
                    ],
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                    onPressed: () => ref.read(hospitalProvider.notifier).refresh(),
                  ),
                ],
              ),
            ),
          ),
          // Legend
          Positioned(
            bottom: 100, right: 16,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10)],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  _legendItem(AppColors.mintGreen, 'AI Verified'),
                  const SizedBox(height: 6),
                  _legendItem(Colors.grey.shade400, 'General'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _legendItem(Color color, String label) {
    return Row(children: [
      Container(width: 12, height: 12, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
      const SizedBox(width: 6),
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _buildLoadingMap() {
    return Stack(children: [
      _buildMap([], null),
      Container(
        color: Colors.black45,
        child: const Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: AppColors.mintGreen),
              SizedBox(height: 16),
              Text('AI is analyzing hospitals for Sara...', style: TextStyle(color: Colors.white, fontSize: 14)),
            ],
          ),
        ),
      ),
    ]);
  }

  Widget _buildMap(List<Hospital> hospitals, BuildContext? context) {
    final center = LatLng(LocationService.mockLat, LocationService.mockLon);
    return FlutterMap(
      options: MapOptions(initialCenter: center, initialZoom: 13.5),
      children: [
        TileLayer(
          urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName: 'com.antigravity.app',
        ),
        MarkerLayer(
          markers: [
            // User location marker
            Marker(
              point: center,
              width: 40, height: 40,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.4), blurRadius: 12, spreadRadius: 2)],
                ),
                child: const Icon(Icons.person_pin_circle_rounded, color: Colors.white, size: 18),
              ),
            ),
            // Hospital markers
            ...hospitals.map((h) => Marker(
              point: LatLng(h.lat, h.lon),
              width: h.isAiVerified ? 50 : 38,
              height: h.isAiVerified ? 50 : 38,
              child: _HospitalMarker(hospital: h),
            )),
          ],
        ),
      ],
    );
  }
}

class _HospitalMarker extends StatelessWidget {
  final Hospital hospital;
  const _HospitalMarker({required this.hospital});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showDetails(context),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        decoration: BoxDecoration(
          color: hospital.isAiVerified ? AppColors.mintGreen : Colors.grey.shade400,
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white, width: 2.5),
          boxShadow: [
            BoxShadow(
              color: (hospital.isAiVerified ? AppColors.mintGreen : Colors.grey).withOpacity(0.4),
              blurRadius: hospital.isAiVerified ? 14 : 6,
              spreadRadius: hospital.isAiVerified ? 2 : 0,
            ),
          ],
        ),
        child: Icon(
          hospital.isAiVerified ? Icons.verified_rounded : Icons.local_hospital_rounded,
          color: Colors.white,
          size: hospital.isAiVerified ? 22 : 16,
        ),
      ),
    );
  }

  void _showDetails(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (hospital.isAiVerified ? AppColors.mintGreen : AppColors.primary).withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.local_hospital_rounded, color: hospital.isAiVerified ? AppColors.mintGreen : AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(hospital.name, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
                  if (hospital.isAiVerified)
                    Container(
                      margin: const EdgeInsets.only(top: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.mintGreen, borderRadius: BorderRadius.circular(20)),
                      child: const Text('✓ AI Verified for Sara', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600)),
                    ),
                ],
              )),
            ]),
            const SizedBox(height: 16),
            if (hospital.specialties.isNotEmpty) ...[
              const Text('Specialties', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
              const SizedBox(height: 6),
              Wrap(spacing: 6, children: hospital.specialties.map((s) => Chip(
                label: Text(s, style: const TextStyle(fontSize: 11)),
                backgroundColor: AppColors.background,
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                padding: const EdgeInsets.symmetric(horizontal: 4),
              )).toList()),
            ],
            if (hospital.rating != null) ...[
              const SizedBox(height: 12),
              Row(children: [
                const Icon(Icons.star_rounded, color: Colors.amber, size: 18),
                const SizedBox(width: 4),
                Text('${hospital.rating}/5.0', style: const TextStyle(fontWeight: FontWeight.w600)),
              ]),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.directions_rounded),
                label: const Text('Get Directions'),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

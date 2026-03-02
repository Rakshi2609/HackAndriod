import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../providers/medicine_provider.dart';
import '../models/medicine.dart';
import '../services/location_service.dart';
import '../providers/hospital_provider.dart';
import '../theme/app_theme.dart';

class PharmacyScreen extends ConsumerStatefulWidget {
  const PharmacyScreen({super.key});

  @override
  ConsumerState<PharmacyScreen> createState() => _PharmacyScreenState();
}

class _PharmacyScreenState extends ConsumerState<PharmacyScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _deliveryController;
  bool _ordered = false;
  double _deliveryProgress = 0.0;

  // Delivery route will be computed at order time using device location
  late LatLng _pharmacy;
  late LatLng _home;
  late LatLng _deliveryIcon;

  @override
  void initState() {
    super.initState();
    _deliveryController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    _deliveryController.addListener(() {
      final t = _deliveryController.value;
      setState(() {
        _deliveryProgress = t;
        _deliveryIcon = LatLng(
          _pharmacy.latitude + (_home.latitude - _pharmacy.latitude) * t,
          _pharmacy.longitude + (_home.longitude - _pharmacy.longitude) * t,
        );
      });
    });
    // initialize with mock values until device location is available
    _pharmacy =
        LatLng(LocationService.mockLat + 0.02, LocationService.mockLon + 0.02);
    _home = LatLng(LocationService.mockLat, LocationService.mockLon);
    _deliveryIcon = _pharmacy;
  }

  @override
  void dispose() {
    _deliveryController.dispose();
    super.dispose();
  }

  void _placeOrder() {
    // Compute route based on device location (if available) and then animate
    final deviceLocAsync = ref.read(deviceLocationProvider);
    deviceLocAsync.when(
      data: (loc) {
        setState(() {
          _pharmacy = LatLng(loc.latitude + 0.02, loc.longitude + 0.02);
          _home = LatLng(loc.latitude, loc.longitude);
          _deliveryIcon = _pharmacy;
          _ordered = true;
        });
        _deliveryController.forward(from: 0);
      },
      loading: () {
        setState(() => _ordered = true);
        _deliveryController.forward(from: 0);
      },
      error: (_, __) {
        setState(() => _ordered = true);
        _deliveryController.forward(from: 0);
      },
    );
  }

  String get _deliveryStatus {
    if (!_ordered) return 'Ready to order';
    if (_deliveryProgress < 0.25) return '📦 Order confirmed — packing...';
    if (_deliveryProgress < 0.5) return '🛵 On the way!';
    if (_deliveryProgress < 0.75) return '🛵 Almost there...';
    if (_deliveryProgress < 1.0) return '🏠 Arriving...';
    return '✅ Delivered!';
  }

  @override
  Widget build(BuildContext context) {
    final deviceLocAsync = ref.watch(deviceLocationProvider);
    final medicinesAsync = ref.watch(medicineProvider);
    final medicines = medicinesAsync.valueOrNull ?? _demoMedicines();
    final center = deviceLocAsync.maybeWhen(
      data: (loc) => LatLng((loc.latitude + _home.latitude) / 2,
          (loc.longitude + _home.longitude) / 2),
      orElse: () => LatLng((_pharmacy.latitude + _home.latitude) / 2,
          (_pharmacy.longitude + _home.longitude) / 2),
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Pharmacy'),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${medicines.length} items',
              style: const TextStyle(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Delivery map
          Expanded(
            flex: 2,
            child: ClipRRect(
              child: Stack(
                children: [
                  FlutterMap(
                    options: MapOptions(
                      initialCenter: center,
                      initialZoom: 13.5,
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.carelytix.app',
                      ),
                      PolylineLayer<Object>(
                        polylines: [
                          Polyline(
                            points: [_pharmacy, _home],
                            color: AppColors.primary.withOpacity(0.4),
                            strokeWidth: 3,
                          ),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _pharmacy,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.local_pharmacy_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          Marker(
                            point: _home,
                            width: 44,
                            height: 44,
                            child: Container(
                              decoration: const BoxDecoration(
                                color: AppColors.mintGreen,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.home_rounded,
                                color: Colors.white,
                                size: 20,
                              ),
                            ),
                          ),
                          if (_ordered)
                            Marker(
                              point: _deliveryIcon,
                              width: 44,
                              height: 44,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.warning,
                                  shape: BoxShape.circle,
                                  boxShadow: [
                                    BoxShadow(
                                      color: AppColors.warning.withOpacity(0.5),
                                      blurRadius: 10,
                                      spreadRadius: 2,
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.delivery_dining_rounded,
                                  color: Colors.white,
                                  size: 22,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                  // Status bar
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.08),
                            blurRadius: 10,
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.delivery_dining_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _deliveryStatus,
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 13,
                            ),
                          ),
                          if (_ordered) ...[
                            const Spacer(),
                            Text(
                              '${(_deliveryProgress * 100).toInt()}%',
                              style: const TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Medicine list
          Expanded(
            flex: 3,
            child: Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    itemCount: medicines.length,
                    itemBuilder: (ctx, i) =>
                        _MedicineCartItem(medicine: medicines[i]),
                  ),
                ),
                // Order button
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Total',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            '₹${(medicines.length * 85 + 49).toStringAsFixed(0)} (incl. delivery)',
                            style: const TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: _ordered ? null : _placeOrder,
                          icon: Icon(
                            _ordered
                                ? Icons.check_rounded
                                : Icons.shopping_cart_checkout_rounded,
                          ),
                          label: Text(
                            _ordered ? 'Order Placed!' : 'Order All Medicines',
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: _ordered
                                ? AppColors.mintGreen
                                : AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Medicine> _demoMedicines() => [
        Medicine(
          name: 'Metformin',
          dosage: '500mg',
          frequency: 'Twice Daily',
          times: ['08:00', '20:00'],
        ),
        Medicine(
          name: 'Lisinopril',
          dosage: '10mg',
          frequency: 'Once Daily',
          times: ['09:00'],
        ),
        Medicine(
          name: 'Atorvastatin',
          dosage: '20mg',
          frequency: 'Once Daily',
          times: ['21:00'],
        ),
      ];
}

class _MedicineCartItem extends StatelessWidget {
  final Medicine medicine;
  const _MedicineCartItem({required this.medicine});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 8),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.medication_rounded,
              color: AppColors.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  medicine.name,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                Text(
                  '${medicine.dosage} · ${medicine.frequency}',
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '₹85',
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

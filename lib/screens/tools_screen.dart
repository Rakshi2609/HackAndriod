import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map_screen.dart';
import '../theme/app_theme.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tools'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Map', icon: Icon(Icons.map_rounded)),
            Tab(text: 'Pharmacy', icon: Icon(Icons.local_pharmacy_rounded))
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const MapScreen(),
          _buildPharmacyTab(),
        ],
      ),
    );
  }

  Widget _buildPharmacyTab() {
    // Dummy data for now
    final pharmacies = [
      {'name': 'HealthPlus Pharmacy', 'distance': '0.8 km'},
      {'name': 'CityCare Pharmacy', 'distance': '1.6 km'},
      {'name': 'Neighborhood Pharmacy', 'distance': '2.1 km'},
    ];

    final medicines = [
      {'name': 'Metformin', 'dosage': '500mg', 'price': '85'},
      {'name': 'Lisinopril', 'dosage': '10mg', 'price': '85'},
      {'name': 'Atorvastatin', 'dosage': '20mg', 'price': '85'},
    ];

    return Column(children: [
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: pharmacies.length,
          itemBuilder: (ctx, i) {
            final p = pharmacies[i];
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: const Icon(Icons.storefront_rounded,
                    color: AppColors.primary),
                title: Text(p['name']!),
                subtitle: Text('${p['distance']} · Open now'),
                trailing: ElevatedButton(
                    onPressed: () =>
                        _showPharmacyDetails(context, p['name']!, medicines),
                    child: const Text('Open')),
              ),
            );
          },
        ),
      ),
    ]);
  }

  void _showPharmacyDetails(
      BuildContext context, String name, List<Map<String, String>> medicines) {
    showModalBottomSheet(
        context: context,
        builder: (_) => Container(
              padding: const EdgeInsets.all(16),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.w800)),
                const SizedBox(height: 12),
                ...medicines.map((m) => ListTile(
                      leading: const Icon(Icons.medication_rounded,
                          color: AppColors.primary),
                      title: Text(m['name']!),
                      subtitle: Text(m['dosage']!),
                      trailing: Text('₹${m['price']!}'),
                    )),
                const SizedBox(height: 8),
                ElevatedButton(
                    onPressed: () {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Order placed (dummy)')));
                    },
                    child: const Text('Order All'))
              ]),
            ));
  }
}

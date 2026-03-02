import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'map_screen.dart';
// Conditional import: use a web-safe stub when `dart:io` is not available.
import '../services/mongo_report_stub.dart'
    if (dart.library.io) '../services/mongo_report_service.dart';
import '../theme/app_theme.dart';

class ToolsScreen extends ConsumerStatefulWidget {
  const ToolsScreen({super.key});

  @override
  ConsumerState<ToolsScreen> createState() => _ToolsScreenState();
}

class _ToolsScreenState extends ConsumerState<ToolsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  Future<List<Map<String, dynamic>>> _reportsFuture = Future.value([]);
  Set<String> _hiddenIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _reportsFuture = _loadReports();
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
            Tab(text: 'Pharmacy', icon: Icon(Icons.local_pharmacy_rounded)),
            Tab(text: 'Reports', icon: Icon(Icons.receipt_long_rounded)),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          const MapScreen(),
          _buildPharmacyTab(),
          _buildReportsTab(),
        ],
      ),
    );
  }

  Widget _buildReportsTab() {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _reportsFuture,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snap.hasError) {
          return Center(child: Text('Error: ${snap.error}'));
        }
        final items = (snap.data ?? [])
            .where((r) => !_hiddenIds.contains((r['_id'] ?? r['id'] ?? '').toString()))
            .toList();
        if (items.isEmpty) return const Center(child: Text('No reports found'));
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (ctx, i) {
            final r = items[i];
            final created = r['created_at'] ?? '';
            final type = r['type'] ?? '';
            final subtype = r['subtype'] ?? '';
            final id = (r['_id'] ?? r['id'] ?? '').toString();
            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                title: Text(
                    '${type.toString().toUpperCase()} ${subtype != '' ? '· $subtype' : ''}'),
                subtitle: Text(created.toString()),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(
                    child: const Text('View'),
                    onPressed: () => showDialog(
                        context: context,
                        builder: (_) => AlertDialog(
                              title: const Text('Report JSON'),
                              content: SingleChildScrollView(
                                  child: Text(JsonEncoder.withIndent('  ')
                                      .convert(r['content'] ?? r))),
                              actions: [
                                TextButton(
                                    onPressed: () => Navigator.pop(context),
                                    child: const Text('Close'))
                              ],
                            )),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    child: const Text('Delete', style: TextStyle(color: Colors.red)),
                    onPressed: () async {
                      final confirm = await showDialog<bool>(
                          context: context,
                          builder: (_) => AlertDialog(
                                title: const Text('Hide report?'),
                                content: const Text(
                                    'This will hide the report from the UI but will not delete it from the database.'),
                                actions: [
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, false),
                                      child: const Text('Cancel')),
                                  TextButton(
                                      onPressed: () => Navigator.pop(context, true),
                                      child: const Text('Hide'))
                                ],
                              ));
                      if (confirm == true) {
                        await _hideReport(id);
                      }
                    },
                  ),
                ]),
              ),
            );
          },
        );
      },
    );
  }

  Future<List<Map<String, dynamic>>> _loadReports() async {
    final svc = MongoReportService();
    await svc.init();
    final all = await svc.fetchAllReports();
    // load hidden ids from prefs
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList('carelytix_hidden_reports') ?? <String>[];
    _hiddenIds = hidden.toSet();
    return all;
  }

  Future<void> _hideReport(String id) async {
    if (id.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final hidden = prefs.getStringList('carelytix_hidden_reports') ?? <String>[];
    if (!hidden.contains(id)) {
      hidden.add(id);
      await prefs.setStringList('carelytix_hidden_reports', hidden);
      _hiddenIds.add(id);
      setState(() {
        _reportsFuture = _loadReports();
      });
    }
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

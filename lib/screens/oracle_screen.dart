import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import '../providers/medicine_provider.dart';
import '../models/medicine.dart';
import '../theme/app_theme.dart';

class OracleScreen extends ConsumerStatefulWidget {
  const OracleScreen({super.key});

  @override
  ConsumerState<OracleScreen> createState() => _OracleScreenState();
}

class _OracleScreenState extends ConsumerState<OracleScreen> with TickerProviderStateMixin {
  late AnimationController _pulseController;
  late AnimationController _cardController;
  late Animation<double> _pulse;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(vsync: this, duration: const Duration(seconds: 2))..repeat(reverse: true);
    _cardController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _pulse = Tween<double>(begin: 0.95, end: 1.05).animate(CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _pickAndScan() async {
    final picker = ImagePicker();
    final xFile = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (xFile == null) return;

    final bytes = await File(xFile.path).readAsBytes();
    final base64Img = base64Encode(bytes);
    await ref.read(medicineProvider.notifier).scanPrescription(base64Img);
    _cardController.forward(from: 0);
  }

  void _loadDemo() {
    ref.read(medicineProvider.notifier).loadDemo();
    _cardController.forward(from: 0);
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicineProvider);

    return Scaffold(
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 200,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(0xFF1A1D2E), Color(0xFF2D9CDB)],
                  ),
                ),
                child: Center(
                  child: ScaleTransition(
                    scale: _pulse,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 80, height: 80,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient: RadialGradient(colors: [AppColors.mintGreen.withOpacity(0.3), Colors.transparent]),
                          ),
                          child: const Icon(Icons.document_scanner_rounded, size: 44, color: AppColors.mintGreen),
                        ),
                        const SizedBox(height: 8),
                        const Text('Oracle Scanner', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                        const Text('AI-powered prescription reader', style: TextStyle(color: Colors.white60, fontSize: 12)),
                      ],
                    ),
                  ),
                ),
              ),
              title: medicinesAsync.hasValue && (medicinesAsync.value?.isNotEmpty ?? false)
                  ? const Text('Your Medicines', style: TextStyle(fontSize: 18))
                  : null,
            ),
            backgroundColor: AppColors.deepNavy,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: medicinesAsync.when(
              loading: () => SliverToBoxAdapter(child: _buildLoading()),
              error: (e, _) => SliverToBoxAdapter(child: _buildError()),
              data: (medicines) => medicines.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmpty())
                  : _buildMedicineList(medicines),
            ),
          ),
        ],
      ),
      floatingActionButton: medicinesAsync.hasValue && (medicinesAsync.value?.isNotEmpty ?? false)
          ? FloatingActionButton.extended(
              onPressed: () async {
                await ref.read(medicineProvider.notifier).scheduleAllReminders();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('✅ All reminders scheduled!'),
                      backgroundColor: AppColors.mintGreen,
                    ),
                  );
                }
              },
              backgroundColor: AppColors.mintGreen,
              icon: const Icon(Icons.notifications_active_rounded, color: Colors.white),
              label: const Text('Schedule All Reminders', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildEmpty() {
    return Column(
      children: [
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.07), blurRadius: 20)],
          ),
          child: Column(children: [
            const Icon(Icons.medication_liquid_rounded, size: 80, color: AppColors.primary),
            const SizedBox(height: 20),
            const Text('Scan Your Prescription', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            const Text('Featherless Vision AI will extract\nyour medicines automatically', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 28),
            ElevatedButton.icon(
              onPressed: _pickAndScan,
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Scan Prescription'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: _loadDemo,
              child: const Text('Use Demo Data →'),
            ),
          ]),
        ),
      ],
    );
  }

  Widget _buildLoading() {
    return const Column(children: [
      SizedBox(height: 80),
      Center(child: CircularProgressIndicator(color: AppColors.primary)),
      SizedBox(height: 20),
      Text('Featherless Vision AI is reading your prescription...', textAlign: TextAlign.center, style: TextStyle(color: AppColors.textSecondary)),
    ]);
  }

  Widget _buildError() {
    return Column(children: [
      const SizedBox(height: 40),
      const Icon(Icons.error_outline_rounded, size: 64, color: AppColors.danger),
      const SizedBox(height: 16),
      const Text('Scan failed. Using demo data.'),
      const SizedBox(height: 12),
      ElevatedButton(onPressed: _loadDemo, child: const Text('Load Demo')),
    ]);
  }

  SliverList _buildMedicineList(List<Medicine> medicines) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (ctx, i) {
          if (i == medicines.length) {
            return const SizedBox(height: 100);
          }
          return _MedicineCard(medicine: medicines[i], index: i);
        },
        childCount: medicines.length + 1,
      ),
    );
  }
}

class _MedicineCard extends StatelessWidget {
  final Medicine medicine;
  final int index;

  const _MedicineCard({required this.medicine, required this.index});

  @override
  Widget build(BuildContext context) {
    final colors = [AppColors.primary, AppColors.mintGreen, AppColors.warning, AppColors.danger];
    final color = colors[index % colors.length];

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: color.withOpacity(0.08), blurRadius: 16, offset: const Offset(0, 4))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: IntrinsicHeight(
          child: Row(
            children: [
              Container(width: 6, color: color),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(child: Text(medicine.name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
                        if (medicine.reminderSet)
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(color: AppColors.mintGreen, borderRadius: BorderRadius.circular(20)),
                            child: const Text('Scheduled', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w700)),
                          ),
                      ]),
                      const SizedBox(height: 6),
                      Row(children: [
                        _pill(Icons.medication_rounded, medicine.dosage, color),
                        const SizedBox(width: 8),
                        _pill(Icons.schedule_rounded, medicine.frequency, color),
                      ]),
                      if (medicine.instructions.isNotEmpty) ...[
                        const SizedBox(height: 8),
                        Text('📌 ${medicine.instructions}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 12)),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        children: medicine.times.map((t) => Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: color.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text('⏰ $t', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
                        )).toList(),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

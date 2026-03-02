import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

class _OracleScreenState extends ConsumerState<OracleScreen>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _glowController;
  late AnimationController _cardController;
  late Animation<double> _scanLine;
  late Animation<double> _glow;
  late Animation<double> _cardFade;

  bool _scanning = false;

  @override
  void initState() {
    super.initState();
    _scanController =
        AnimationController(vsync: this, duration: const Duration(seconds: 2));
    _glowController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..repeat(reverse: true);
    _cardController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600));
    _scanLine = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _scanController, curve: Curves.easeInOut));
    _glow = Tween<double>(begin: 0.7, end: 1.0).animate(_glowController);
    _cardFade = Tween<double>(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _scanController.dispose();
    _glowController.dispose();
    _cardController.dispose();
    super.dispose();
  }

  Future<void> _startScan(ImageSource source) async {
    setState(() => _scanning = true);
    _scanController.repeat();

    try {
      String base64Img = '';
      if (!kIsWeb) {
        final picker = ImagePicker();
        final xFile = await picker.pickImage(source: source, imageQuality: 85);
        if (xFile == null) {
          setState(() => _scanning = false);
          _scanController.stop();
          return;
        }
        final bytes = await File(xFile.path).readAsBytes();
        base64Img = base64Encode(bytes);
      }

      // Simulate 2.5s scanning animation
      await Future.delayed(const Duration(milliseconds: 2500));
      _scanController.stop();

      final result = await ref
          .read(medicineProvider.notifier)
          .scanPrescription(base64Img.isNotEmpty ? base64Img : 'demo');
      // If analyzer classified as non-prescription report, notify user where it's stored
      if (result != null && result['type'] == 'report') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(
                'Saved medical report (${result['subtype'] ?? 'unknown'}) to Tools → Reports'),
            backgroundColor: AppColors.primary,
          ));
        }
      }
      _cardController.forward(from: 0);
    } catch (_) {
      ref.read(medicineProvider.notifier).loadDemo();
      _cardController.forward(from: 0);
    }

    setState(() => _scanning = false);
  }

  @override
  Widget build(BuildContext context) {
    final medicinesAsync = ref.watch(medicineProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 260,
            pinned: true,
            backgroundColor: AppColors.deepNavy,
            flexibleSpace: FlexibleSpaceBar(
              background: _buildHero(),
            ),
            title: medicinesAsync.hasValue &&
                    (medicinesAsync.value?.isNotEmpty ?? false)
                ? const Text('AI Scan Results',
                    style: TextStyle(fontSize: 16, color: Colors.white))
                : null,
          ),
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: medicinesAsync.when(
              loading: () => SliverToBoxAdapter(child: _buildLoading()),
              error: (_, __) => SliverToBoxAdapter(child: _buildEmpty()),
              data: (meds) => meds.isEmpty
                  ? SliverToBoxAdapter(child: _buildEmpty())
                  : _buildResults(meds),
            ),
          ),
        ],
      ),
      floatingActionButton: medicinesAsync.valueOrNull?.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () async {
                await ref
                    .read(medicineProvider.notifier)
                    .scheduleAllReminders();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                    content: Text('✅ All reminders scheduled by AI!'),
                    backgroundColor: AppColors.mintGreen,
                  ));
                }
              },
              backgroundColor: AppColors.mintGreen,
              icon: const Icon(Icons.notifications_active_rounded,
                  color: Colors.white),
              label: const Text('Schedule All',
                  style: TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700)),
            )
          : null,
    );
  }

  Widget _buildHero() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0D1B2A), Color(0xFF0A3060), Color(0xFF2D9CDB)],
        ),
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Background glow
          AnimatedBuilder(
            animation: _glow,
            builder: (_, __) => Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.mintGreen.withOpacity(0.05 * _glow.value),
                boxShadow: [
                  BoxShadow(
                      color:
                          AppColors.mintGreen.withOpacity(0.15 * _glow.value),
                      blurRadius: 60,
                      spreadRadius: 20)
                ],
              ),
            ),
          ),

          // Scanner frame
          if (_scanning)
            SizedBox(
              width: 180,
              height: 180,
              child: Stack(children: [
                // Corner brackets
                ..._buildCorners(),
                // Laser scan line
                AnimatedBuilder(
                  animation: _scanLine,
                  builder: (_, __) => Positioned(
                    top: _scanLine.value * 160,
                    left: 0,
                    right: 0,
                    child: Container(
                      height: 2.5,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [
                          Colors.transparent,
                          AppColors.mintGreen,
                          AppColors.mintGreen,
                          Colors.transparent
                        ]),
                        boxShadow: [
                          BoxShadow(
                              color: AppColors.mintGreen.withOpacity(0.8),
                              blurRadius: 8,
                              spreadRadius: 2)
                        ],
                      ),
                    ),
                  ),
                ),
              ]),
            )
          else
            Column(mainAxisSize: MainAxisSize.min, children: [
              AnimatedBuilder(
                animation: _glow,
                builder: (_, __) => Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.mintGreen.withOpacity(0.15 * _glow.value),
                    shape: BoxShape.circle,
                    border: Border.all(
                        color:
                            AppColors.mintGreen.withOpacity(0.5 * _glow.value),
                        width: 2),
                  ),
                  child: const Icon(Icons.document_scanner_rounded,
                      size: 42, color: AppColors.mintGreen),
                ),
              ),
              const SizedBox(height: 12),
              const Text('Oracle Scanner',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Featherless Vision AI · Full Detail Extraction',
                  style: TextStyle(
                      color: Colors.white54, fontSize: 11, letterSpacing: 0.5)),
            ]),

          // Scan label overlay
          if (_scanning)
            const Positioned(
              bottom: 20,
              child: Column(children: [
                Text('🔬 AI Analyzing...',
                    style: TextStyle(
                        color: AppColors.mintGreen,
                        fontWeight: FontWeight.w700,
                        fontSize: 15)),
                SizedBox(height: 4),
                Text('Extracting dosage, warnings & more',
                    style: TextStyle(color: Colors.white54, fontSize: 11)),
              ]),
            ),
        ],
      ),
    );
  }

  List<Widget> _buildCorners() {
    const color = AppColors.mintGreen;
    const thick = 3.0;
    const len = 20.0;
    return [
      Positioned(
          top: 0, left: 0, child: _corner(color, thick, len, true, true)),
      Positioned(
          top: 0, right: 0, child: _corner(color, thick, len, true, false)),
      Positioned(
          bottom: 0, left: 0, child: _corner(color, thick, len, false, true)),
      Positioned(
          bottom: 0, right: 0, child: _corner(color, thick, len, false, false)),
    ];
  }

  Widget _corner(Color c, double t, double l, bool top, bool left) {
    return SizedBox(
        width: l,
        height: l,
        child: CustomPaint(painter: _CornerPainter(c, t, top, left)));
  }

  Widget _buildEmpty() {
    return Column(children: [
      const SizedBox(height: 20),
      Container(
        padding: const EdgeInsets.all(28),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
              BoxShadow(
                  color: AppColors.primary.withOpacity(0.06), blurRadius: 20)
            ]),
        child: Column(children: [
          const Icon(Icons.medication_liquid_rounded,
              size: 72, color: AppColors.primary),
          const SizedBox(height: 16),
          const Text('Scan Your Prescription',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
              'Featherless Vision AI extracts every detail:\nDosage, mg, side effects, warnings & more',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4)),
          const SizedBox(height: 24),
          Row(children: [
            Expanded(
                child: ElevatedButton.icon(
              onPressed: () => _startScan(ImageSource.camera),
              icon: const Icon(Icons.camera_alt_rounded),
              label: const Text('Camera'),
            )),
            const SizedBox(width: 12),
            Expanded(
                child: OutlinedButton.icon(
              onPressed: () => _startScan(ImageSource.gallery),
              icon: const Icon(Icons.photo_library_rounded),
              label: const Text('Gallery'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: const BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 14)),
            )),
          ]),
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: () {
              ref.read(medicineProvider.notifier).loadDemo();
              _cardController.forward(from: 0);
            },
            icon: const Icon(Icons.science_rounded, size: 16),
            label: const Text('Use Demo Prescription'),
          ),
        ]),
      ),
    ]);
  }

  Widget _buildLoading() {
    return const Column(children: [
      SizedBox(height: 60),
      Center(child: CircularProgressIndicator(color: AppColors.mintGreen)),
      SizedBox(height: 16),
      Text('Featherless AI reading every detail...',
          textAlign: TextAlign.center,
          style: TextStyle(
              color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
    ]);
  }

  SliverList _buildResults(List<Medicine> meds) {
    return SliverList(
        delegate: SliverChildBuilderDelegate(
      (ctx, i) {
        if (i == meds.length) return const SizedBox(height: 100);
        return FadeTransition(
          opacity: _cardFade,
          child: _MedicineDetailCard(medicine: meds[i], index: i),
        );
      },
      childCount: meds.length + 1,
    ));
  }
}

class _CornerPainter extends CustomPainter {
  final Color color;
  final double thickness;
  final bool top, left;
  _CornerPainter(this.color, this.thickness, this.top, this.left);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = thickness
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;
    if (top && left) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
      canvas.drawLine(Offset.zero, Offset(0, size.height), paint);
    }
    if (top && !left) {
      canvas.drawLine(Offset.zero, Offset(size.width, 0), paint);
      canvas.drawLine(
          Offset(size.width, 0), Offset(size.width, size.height), paint);
    }
    if (!top && left) {
      canvas.drawLine(Offset(0, size.height), const Offset(0, 0), paint);
      canvas.drawLine(
          Offset(0, size.height), Offset(size.width, size.height), paint);
    }
    if (!top && !left) {
      canvas.drawLine(
          Offset(size.width, size.height), Offset(0, size.height), paint);
      canvas.drawLine(
          Offset(size.width, size.height), Offset(size.width, 0), paint);
    }
  }

  @override
  bool shouldRepaint(_) => false;
}

class _MedicineDetailCard extends StatefulWidget {
  final Medicine medicine;
  final int index;
  const _MedicineDetailCard({required this.medicine, required this.index});
  @override
  State<_MedicineDetailCard> createState() => _MedicineDetailCardState();
}

class _MedicineDetailCardState extends State<_MedicineDetailCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final colors = [
      AppColors.primary,
      AppColors.mintGreen,
      AppColors.warning,
      AppColors.danger
    ];
    final color = colors[widget.index % colors.length];
    final m = widget.medicine;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 16,
              offset: const Offset(0, 4))
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Column(children: [
          // Color bar + main info
          IntrinsicHeight(
            child: Row(children: [
              Container(width: 5, color: color),
              Expanded(
                  child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        Expanded(
                            child: Text(m.name,
                                style: const TextStyle(
                                    fontSize: 17,
                                    fontWeight: FontWeight.w800))),
                        if (m.reminderSet)
                          Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                  color: AppColors.mintGreen,
                                  borderRadius: BorderRadius.circular(20)),
                              child: const Text('Scheduled',
                                  style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 9,
                                      fontWeight: FontWeight.w700))),
                      ]),
                      if (m.genericName.isNotEmpty)
                        Text(m.genericName,
                            style: const TextStyle(
                                color: AppColors.textSecondary, fontSize: 12)),
                      if (m.category.isNotEmpty)
                        Container(
                            margin: const EdgeInsets.only(top: 4),
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6)),
                            child: Text(m.category,
                                style: TextStyle(
                                    color: color,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600))),
                      const SizedBox(height: 10),
                      Wrap(spacing: 6, runSpacing: 6, children: [
                        _pill(Icons.medication_rounded, m.dosage, color),
                        _pill(Icons.schedule_rounded, m.frequency, color),
                        if (m.duration.isNotEmpty)
                          _pill(Icons.calendar_today_rounded, m.duration,
                              Colors.grey),
                      ]),
                      if (m.instructions.isNotEmpty)
                        Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text('📌 ${m.instructions}',
                                style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12))),
                      Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: m.times
                              .map((t) => Container(
                                    margin: const EdgeInsets.only(top: 8),
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(
                                        color: color.withOpacity(0.08),
                                        borderRadius: BorderRadius.circular(8)),
                                    child: Text('⏰ $t',
                                        style: TextStyle(
                                            color: color,
                                            fontSize: 12,
                                            fontWeight: FontWeight.w600)),
                                  ))
                              .toList()),
                      // Expand toggle
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() => _expanded = !_expanded),
                        child: Row(children: [
                          Text(_expanded ? 'Less details' : 'Full AI details ↓',
                              style: TextStyle(
                                  color: color,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700)),
                          Icon(
                              _expanded ? Icons.expand_less : Icons.expand_more,
                              color: color,
                              size: 18),
                        ]),
                      ),
                    ]),
              )),
            ]),
          ),

          // Expanded details
          if (_expanded)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Divider(),
                    if (m.sideEffects.isNotEmpty)
                      _detailSection(
                          '⚠️ Side Effects', m.sideEffects, AppColors.warning),
                    if (m.warnings.isNotEmpty)
                      _detailSection(
                          '🚫 Warnings', m.warnings, AppColors.danger),
                    if (m.interactions.isNotEmpty)
                      _detailSection('💊 Drug Interactions', m.interactions,
                          AppColors.primary),
                    if (m.prescribedBy.isNotEmpty)
                      Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text('👨‍⚕️ Dr: ${m.prescribedBy}',
                              style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary))),
                    if (m.rxNumber.isNotEmpty)
                      Text('Rx: ${m.rxNumber}',
                          style: const TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontFamily: 'monospace')),
                  ]),
            ),
        ]),
      ),
    );
  }

  Widget _pill(IconData icon, String label, Color color) {
    if (label.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 12, color: color),
        const SizedBox(width: 4),
        Text(label,
            style: TextStyle(
                fontSize: 11, color: color, fontWeight: FontWeight.w600)),
      ]),
    );
  }

  Widget _detailSection(String title, List<String> items, Color color) {
    return Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title,
              style: TextStyle(
                  fontWeight: FontWeight.w700, fontSize: 12, color: color)),
          const SizedBox(height: 4),
          Wrap(
              spacing: 6,
              runSpacing: 4,
              children: items
                  .map((s) => Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                            color: color.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(6),
                            border: Border.all(color: color.withOpacity(0.2))),
                        child: Text(s,
                            style: TextStyle(fontSize: 11, color: color)),
                      ))
                  .toList()),
        ]));
  }
}

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:ui';
import 'dart:math';
import 'package:fl_chart/fl_chart.dart';
import '../providers/health_profile_provider.dart';
import '../models/health_profile.dart';
import '../theme/app_theme.dart';

class DoctorDashboardScreen extends ConsumerStatefulWidget {
  const DoctorDashboardScreen({super.key});

  @override
  ConsumerState<DoctorDashboardScreen> createState() => _DoctorDashboardScreenState();
}

class _DoctorDashboardScreenState extends ConsumerState<DoctorDashboardScreen>
    with TickerProviderStateMixin {
  late AnimationController _heartController;
  late List<FlSpot> _heartRateData;
  bool _isMuted = false;
  bool _isCameraOff = false;
  bool _prescriptionSent = false;
  final Random _random = Random();
  int _heartRate = 78;

  @override
  void initState() {
    super.initState();
    _heartController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _heartRateData = _generateHeartData();
    _startHeartRateSimulation();
  }

  List<FlSpot> _generateHeartData() {
    return List.generate(20, (i) => FlSpot(i.toDouble(), 70 + _random.nextDouble() * 20));
  }

  void _startHeartRateSimulation() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      setState(() {
        _heartRate = 72 + _random.nextInt(20);
        _heartRateData = [..._heartRateData.skip(1).map((s) => FlSpot(s.x - 1, s.y)), FlSpot(19, 70 + _random.nextDouble() * 20)];
      });
      return true;
    });
  }

  @override
  void dispose() {
    _heartController.dispose();
    super.dispose();
  }

  void _pushPrescription() {
    ref.read(digitalPrescriptionProvider.notifier).state =
        'Metformin 500mg - Twice Daily\nLinsinopril 10mg - Once Daily\nAtorvastatin 20mg - Once at night\n\n— Dr. Anil Kumar, MD\nDate: ${DateTime.now().day}/${DateTime.now().month}/${DateTime.now().year}';
    setState(() => _prescriptionSent = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('✅ Digital Prescription sent to Sara\'s Vault'), backgroundColor: AppColors.mintGreen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final profile = HealthProfile.sara;
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // Simulated video background
          _buildVideoBackground(),

          // Top bar overlay
          Positioned(
            top: 0, left: 0, right: 0,
            child: _buildTopBar(context),
          ),

          // Right side patient info panel
          Positioned(
            top: 80, right: 0,
            child: _buildPatientPanel(profile),
          ),

          // Heart Rate chart
          Positioned(
            bottom: 180, left: 16, right: 16,
            child: _buildHeartRateChart(),
          ),

          // Bottom controls
          Positioned(
            bottom: 0, left: 0, right: 0,
            child: _buildBottomControls(),
          ),
        ],
      ),
    );
  }

  Widget _buildVideoBackground() {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0A1628), Color(0xFF1A2B40), Color(0xFF0D1117)],
        ),
      ),
      child: Center(
        child: CircleAvatar(
          radius: 80,
          backgroundColor: AppColors.primary.withOpacity(0.2),
          child: const Text('SM', style: TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 8, bottom: 12, left: 20, right: 20),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.4),
            border: Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle),
              child: const Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
            ),
            const SizedBox(width: 8),
            const Text('LIVE • Doctor Mode', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 15)),
            const Spacer(),
            Text('Sara Miller · ${HealthProfile.sara.hashedId}', style: const TextStyle(color: Colors.white54, fontSize: 12)),
          ]),
        ),
      ),
    );
  }

  Widget _buildPatientPanel(HealthProfile profile) {
    return ClipRRect(
      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: 180,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            border: Border(left: BorderSide(color: Colors.white.withOpacity(0.15)), top: BorderSide(color: Colors.white.withOpacity(0.15))),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Verified History', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12)),
              Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 8), color: Colors.white12),
              _patientInfoRow('🩸', 'Blood', profile.bloodGroup),
              const SizedBox(height: 6),
              ...profile.conditions.map((c) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _patientInfoRow('🏥', 'Dx', c),
              )),
              ...profile.allergies.map((a) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: _patientInfoRow('⚠️', 'Allergy', a),
              )),
              Container(height: 1, margin: const EdgeInsets.symmetric(vertical: 8), color: Colors.white12),
              Text('Glucose: ${profile.lastGlucoseReading} mg/dL', style: TextStyle(color: AppColors.warning, fontSize: 11, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.05), borderRadius: BorderRadius.circular(6)),
                child: Text(profile.hashedId, style: const TextStyle(color: Colors.white38, fontSize: 9, fontFamily: 'monospace')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _patientInfoRow(String emoji, String label, String value) {
    return Row(children: [
      Text(emoji, style: const TextStyle(fontSize: 10)),
      const SizedBox(width: 4),
      Expanded(child: Text(value, style: const TextStyle(color: Colors.white70, fontSize: 10), overflow: TextOverflow.ellipsis)),
    ]);
  }

  Widget _buildHeartRateChart() {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          height: 80,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(children: [
            AnimatedBuilder(
              animation: _heartController,
              builder: (_, __) => Transform.scale(
                scale: 0.9 + _heartController.value * 0.2,
                child: const Icon(Icons.favorite_rounded, color: AppColors.danger, size: 24),
              ),
            ),
            const SizedBox(width: 8),
            Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('$_heartRate', style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
              const Text('BPM', style: TextStyle(color: Colors.white38, fontSize: 10)),
            ]),
            const SizedBox(width: 12),
            Expanded(
              child: LineChart(
                LineChartData(
                  gridData: const FlGridData(show: false),
                  titlesData: const FlTitlesData(show: false),
                  borderData: FlBorderData(show: false),
                  minY: 60, maxY: 100,
                  lineBarsData: [
                    LineChartBarData(
                      spots: _heartRateData,
                      isCurved: true,
                      color: AppColors.danger,
                      barWidth: 2,
                      dotData: const FlDotData(show: false),
                      belowBarData: BarAreaData(show: true, color: AppColors.danger.withOpacity(0.1)),
                    ),
                  ],
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _buildBottomControls() {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.5),
            border: Border(top: BorderSide(color: Colors.white.withOpacity(0.1))),
          ),
          child: Row(children: [
            _controlBtn(
              icon: _isMuted ? Icons.mic_off_rounded : Icons.mic_rounded,
              label: _isMuted ? 'Unmute' : 'Mute',
              color: _isMuted ? AppColors.warning : Colors.white,
              onTap: () => setState(() => _isMuted = !_isMuted),
            ),
            const SizedBox(width: 12),
            _controlBtn(
              icon: _isCameraOff ? Icons.videocam_off_rounded : Icons.videocam_rounded,
              label: _isCameraOff ? 'Camera On' : 'Camera',
              color: _isCameraOff ? AppColors.warning : Colors.white,
              onTap: () => setState(() => _isCameraOff = !_isCameraOff),
            ),
            const Spacer(),
            // Push Prescription Button
            GestureDetector(
              onTap: _prescriptionSent ? null : _pushPrescription,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: _prescriptionSent
                      ? [AppColors.mintGreen, const Color(0xFF00A878)]
                      : [AppColors.primary, const Color(0xFF1A6B9A)]),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12)],
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Icon(_prescriptionSent ? Icons.check_circle_rounded : Icons.send_rounded, color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(_prescriptionSent ? 'Sent!' : 'Push Rx', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13)),
                ]),
              ),
            ),
            const SizedBox(width: 12),
            // End call button
            GestureDetector(
              onTap: () => _showEndCallDialog(),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.danger, shape: BoxShape.circle, boxShadow: [BoxShadow(color: AppColors.danger.withOpacity(0.4), blurRadius: 12)]),
                child: const Icon(Icons.call_end_rounded, color: Colors.white, size: 22),
              ),
            ),
          ]),
        ),
      ),
    );
  }

  Widget _controlBtn({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle, border: Border.all(color: Colors.white.withOpacity(0.2))),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 4),
        Text(label, style: const TextStyle(color: Colors.white54, fontSize: 10)),
      ]),
    );
  }

  void _showEndCallDialog() {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('End Consultation?'),
        content: const Text('The session with Sara Miller will be ended.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () { Navigator.pop(context); },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('End Call'),
          ),
        ],
      ),
    );
  }
}

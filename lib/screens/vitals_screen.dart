import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ──────────────────────────────────────────────
//  PPG Waveform Painter
// ──────────────────────────────────────────────
class _WavePainter extends CustomPainter {
  final List<double> samples;
  _WavePainter(this.samples);

  @override
  void paint(Canvas canvas, Size size) {
    if (samples.length < 2) return;
    final paint = Paint()
      ..color = const Color(0xFFEB5757)
      ..strokeWidth = 2.0
      ..style = PaintingStyle.stroke;

    final min = samples.reduce((a, b) => a < b ? a : b);
    final max = samples.reduce((a, b) => a > b ? a : b);
    final range = (max - min).abs();
    if (range < 0.001) return;

    final step = size.width / (samples.length - 1);
    final path = Path();
    for (var i = 0; i < samples.length; i++) {
      final x = i * step;
      final y = size.height - ((samples[i] - min) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_WavePainter old) => true;
}

// ──────────────────────────────────────────────
//  VitalsScreen
// ──────────────────────────────────────────────
class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  static const int _collectSeconds = 60;
  static const int _minSamplesForReport = 60;

  CameraController? _controller;
  bool _scanning = false;
  bool _torchOn = false;
  int _elapsed = 0;

  // raw samples: {t: ms, r: red avg, g: green avg}
  final List<Map<String, double>> _raw = [];
  // down-sampled for waveform display (max 200 pts)
  final List<double> _wave = [];

  // live estimates
  int _liveBpm = 0;

  // final report
  Map<String, dynamic>? _report;

  Timer? _bpmTimer;
  Timer? _clockTimer;

  @override
  void dispose() {
    _bpmTimer?.cancel();
    _clockTimer?.cancel();
    _controller?.dispose();
    super.dispose();
  }

  // ── Camera helpers ──────────────────────────

  Future<void> _startScan() async {
    try {
      final cams = await availableCameras();
      if (cams.isEmpty) {
        _showSnack('No cameras found on this device.');
        return;
      }
      final back = cams.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cams.first,
      );
      _controller =
          CameraController(back, ResolutionPreset.low, enableAudio: false);
      await _controller!.initialize();
      await _controller!.setFlashMode(FlashMode.torch);

      setState(() {
        _scanning = true;
        _torchOn = true;
        _elapsed = 0;
        _report = null;
        _raw.clear();
        _wave.clear();
        _liveBpm = 0;
      });

      _controller!.startImageStream(_onFrame);

      // Update BPM estimate every 2 s
      _bpmTimer = Timer.periodic(const Duration(seconds: 2), (_) {
        _computeLiveBpm();
        setState(() {});
      });

      // Count down collection window
      _clockTimer = Timer.periodic(const Duration(seconds: 1), (t) {
        _elapsed++;
        if (_elapsed >= _collectSeconds) {
          t.cancel();
          _finalise();
        } else {
          setState(() {});
        }
      });
    } catch (e) {
      _showSnack('Camera error: $e');
    }
  }

  Future<void> _stopScan() async {
    _bpmTimer?.cancel();
    _clockTimer?.cancel();
    try {
      await _controller?.stopImageStream();
      await _controller?.setFlashMode(FlashMode.off);
      await _controller?.dispose();
    } catch (_) {}
    _controller = null;
    setState(() {
      _scanning = false;
      _torchOn = false;
      _elapsed = 0;
    });
  }

  // ── Frame processing ─────────────────────────

  void _onFrame(CameraImage img) {
    try {
      // YUV420 or BGRA: extract per-pixel R and G averages
      final planes = img.planes;
      if (planes.isEmpty) return;

      double rAvg = 0, gAvg = 0;

      if (planes.length >= 3) {
        // YUV420 - plane 0 = Y (luma), plane 1 = U (Cb), plane 2 = V (Cr)
        // Approximate R and G from YUV:
        // R ≈ Y + 1.402*(V-128)
        // G ≈ Y - 0.344*(U-128) - 0.714*(V-128)
        final yPlane = planes[0].bytes;
        final uPlane = planes[1].bytes;
        final vPlane = planes[2].bytes;
        final total = yPlane.length;
        final step = max(1, total ~/ 300);
        double rSum = 0, gSum = 0;
        int count = 0;
        for (var i = 0; i < total; i += step) {
          final y = yPlane[i].toDouble();
          final uvIdx =
              (i ~/ (img.width)) * (img.width ~/ 2) + ((i % img.width) ~/ 2);
          final u = uvIdx < uPlane.length ? uPlane[uvIdx].toDouble() : 128.0;
          final v = uvIdx < vPlane.length ? vPlane[uvIdx].toDouble() : 128.0;
          rSum += (y + 1.402 * (v - 128)).clamp(0, 255);
          gSum += (y - 0.344 * (u - 128) - 0.714 * (v - 128)).clamp(0, 255);
          count++;
        }
        if (count > 0) {
          rAvg = rSum / count;
          gAvg = gSum / count;
        }
      } else {
        // Single-plane (BGRA / grayscale) fallback
        final bytes = planes[0].bytes;
        final step = max(1, bytes.length ~/ 300);
        int sum = 0;
        int count = 0;
        for (var i = 0; i < bytes.length; i += step) {
          sum += bytes[i];
          count++;
        }
        rAvg = gAvg = (count > 0 ? sum / count : 0).toDouble();
      }

      final t = DateTime.now().millisecondsSinceEpoch.toDouble();
      _raw.add({'t': t, 'r': rAvg, 'g': gAvg});

      // Keep only last 15 s of data
      final cutoff = t - 15000;
      while (_raw.isNotEmpty && _raw.first['t']! < cutoff) {
        _raw.removeAt(0);
      }

      // Down-sample for waveform
      _wave.add(rAvg);
      if (_wave.length > 200) _wave.removeAt(0);
    } catch (_) {}
  }

  // ── Signal analysis ──────────────────────────

  List<double> _smooth(List<double> v, {int w = 5}) {
    final out = <double>[];
    for (var i = 0; i < v.length; i++) {
      final lo = max(0, i - w ~/ 2);
      final hi = min(v.length - 1, i + w ~/ 2);
      double s = 0;
      for (var j = lo; j <= hi; j++) {
        s += v[j];
      }
      out.add(s / (hi - lo + 1));
    }
    return out;
  }

  /// Returns peak timestamps (ms) from the raw sample list
  List<double> _detectPeaks(List<Map<String, double>> samples) {
    if (samples.length < 10) return [];
    final vals = samples.map((e) => e['r']!).toList();
    final sm = _smooth(vals);
    final mean = sm.reduce((a, b) => a + b) / sm.length;
    final variance =
        sm.map((v) => (v - mean) * (v - mean)).reduce((a, b) => a + b) /
            sm.length;
    final std = sqrt(variance);

    final peaks = <double>[];
    for (var i = 1; i < sm.length - 1; i++) {
      if (sm[i] > sm[i - 1] && sm[i] > sm[i + 1] && sm[i] > mean + std * 0.4) {
        peaks.add(samples[i]['t']!);
      }
    }
    return peaks;
  }

  void _computeLiveBpm() {
    final peaks = _detectPeaks(_raw);
    if (peaks.length < 2) return;
    final intervals = List.generate(
        peaks.length - 1, (i) => (peaks[i + 1] - peaks[i]) / 1000.0);
    if (intervals.isEmpty) return;
    final avg = intervals.reduce((a, b) => a + b) / intervals.length;
    final bpm = (60.0 / avg).round();
    if (bpm > 30 && bpm < 200) _liveBpm = bpm;
  }

  void _finalise() async {
    await _stopScan();

    if (_raw.length < _minSamplesForReport) {
      setState(() {
        _report = {
          'error': 'Not enough data. Hold the camera steady with torch on.',
        };
      });
      return;
    }

    final peaks = _detectPeaks(_raw);

    if (peaks.length < 10) {
      setState(() {
        _report = {
          'error':
              'Could not detect heartbeat. Try again: cover lens completely and turn torch on.',
        };
      });
      return;
    }

    // ── RR intervals (ms) ───────────────────────
    final rr =
        List.generate(peaks.length - 1, (i) => (peaks[i + 1] - peaks[i]));

    // ── BPM (median interval) ───────────────────
    final sorted = List<double>.from(rr)..sort();
    final medianRr = sorted[sorted.length ~/ 2];
    final bpm = (60000.0 / medianRr).round();

    // ── HRV – RMSSD (ms) ────────────────────────
    double rmssd = 0;
    if (rr.length >= 2) {
      double sumSq = 0;
      for (var i = 1; i < rr.length; i++) {
        sumSq += pow(rr[i] - rr[i - 1], 2);
      }
      rmssd = sqrt(sumSq / (rr.length - 1));
    }

    // ── SpO2 approx (red / green AC/DC ratio) ───
    final rVals = _raw.map((e) => e['r']!).toList();
    final gVals = _raw.map((e) => e['g']!).toList();
    double spo2 = 0;
    {
      final rDC = rVals.reduce((a, b) => a + b) / rVals.length;
      final gDC = gVals.reduce((a, b) => a + b) / gVals.length;
      final rAC = rVals.map((v) => (v - rDC).abs()).reduce((a, b) => a + b) /
          rVals.length;
      final gAC = gVals.map((v) => (v - gDC).abs()).reduce((a, b) => a + b) /
          gVals.length;
      if (gDC > 0 && rDC > 0 && gAC > 0) {
        final ratio = (rAC / rDC) / (gAC / gDC);
        // Empirical calibration: SpO2 ≈ 110 − 25·ratio (common phone PPG heuristic)
        spo2 = (110 - 25 * ratio).clamp(85, 100);
      }
    }

    // ── Stress level from RMSSD ──────────────────
    // RMSSD > 50 ms → relaxed, 20–50 → moderate, < 20 → stressed
    String stress;
    Color stressColor;
    if (rmssd > 50) {
      stress = 'Relaxed 😌';
      stressColor = AppColors.accent;
    } else if (rmssd > 20) {
      stress = 'Moderate 😐';
      stressColor = AppColors.warning;
    } else {
      stress = 'High Stress 😰';
      stressColor = AppColors.danger;
    }

    // ── BPM zone ────────────────────────────────
    String bpmZone;
    Color bpmColor;
    if (bpm < 60) {
      bpmZone = 'Low (Bradycardia)';
      bpmColor = AppColors.primary;
    } else if (bpm <= 100) {
      bpmZone = 'Normal';
      bpmColor = AppColors.accent;
    } else {
      bpmZone = 'High (Tachycardia)';
      bpmColor = AppColors.danger;
    }

    setState(() {
      _report = {
        'bpm': bpm,
        'bpmZone': bpmZone,
        'bpmColor': bpmColor,
        'hrv': rmssd.round(),
        'spo2': spo2.round(),
        'stress': stress,
        'stressColor': stressColor,
        'peaks': peaks.length,
        'samples': _raw.length,
      };
    });
  }

  // ── Helpers ─────────────────────────────────

  void _showSnack(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── UI ───────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return _webPlaceholder();
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        _headerCard(),
        const SizedBox(height: 16),
        if (_scanning) ...[
          _waveformCard(),
          const SizedBox(height: 16),
          _liveStatsCard(),
        ],
        if (!_scanning && _report != null) ...[
          _reportCard(),
        ],
        if (!_scanning && _report == null) ...[
          _instructionCard(),
        ],
      ]),
    );
  }

  // ── Sub-widgets ──────────────────────────────

  Widget _webPlaceholder() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: const [
          Icon(Icons.warning_amber_rounded, size: 52, color: Colors.orange),
          SizedBox(height: 16),
          Text('Vitals scanner is not available on Web.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          SizedBox(height: 8),
          Text(
              'Run the app on a physical Android or iOS device with a rear camera.',
              textAlign: TextAlign.center),
        ]),
      ),
    );
  }

  Widget _headerCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primary, AppColors.primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.3),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Row(children: [
        const Icon(Icons.favorite, color: Colors.white, size: 36),
        const SizedBox(width: 12),
        Expanded(
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Vitals Scanner',
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(
              _scanning
                  ? '${_collectSeconds - _elapsed}s remaining  •  ${_torchOn ? "Torch ON 🔦" : "Torch OFF"}'
                  : 'Heart Rate • SpO₂ • HRV • Stress',
              style: const TextStyle(color: Colors.white70, fontSize: 13),
            ),
          ]),
        ),
        const SizedBox(width: 8),
        _scanning
            ? ElevatedButton.icon(
                onPressed: _stopScan,
                icon: const Icon(Icons.stop, size: 18),
                label: const Text('Stop'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.danger,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8)),
              )
            : ElevatedButton.icon(
                onPressed: _startScan,
                icon: const Icon(Icons.play_arrow, size: 18),
                label: const Text('Start'),
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: AppColors.primary,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 8)),
              ),
      ]),
    );
  }

  Widget _instructionCard() {
    final steps = [
      '1. Place the rear camera firmly against your left chest.',
      '2. Cover the lens completely with your finger for fingertip mode.',
      '3. Keep still for 60 seconds.',
      '4. Tap Start — torch will activate automatically.',
    ];
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.06), blurRadius: 10),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.info_outline, color: AppColors.primary),
            const SizedBox(width: 8),
            const Text('How to use',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ]),
          const SizedBox(height: 12),
          ...steps.map((s) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Text(s,
                    style: const TextStyle(
                        fontSize: 14, color: Color(0xFF7A8BA0))),
              )),
        ],
      ),
    );
  }

  Widget _waveformCard() {
    return Container(
      height: 120,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1D2E),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.show_chart, color: Colors.redAccent, size: 16),
            const SizedBox(width: 6),
            const Text('Live PPG Signal',
                style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
            const Spacer(),
            Text('${_elapsed}s / ${_collectSeconds}s',
                style: const TextStyle(color: Colors.white54, fontSize: 11)),
          ]),
          const SizedBox(height: 8),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: CustomPaint(
                painter: _WavePainter(List.from(_wave)),
                child: Container(),
              ),
            ),
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: _collectSeconds > 0 ? _elapsed / _collectSeconds : 0,
            backgroundColor: Colors.white12,
            color: AppColors.primary,
            minHeight: 3,
          ),
        ],
      ),
    );
  }

  Widget _liveStatsCard() {
    return Row(children: [
      _statPill('BPM', _liveBpm == 0 ? '—' : '$_liveBpm', Icons.favorite,
          Colors.redAccent),
      const SizedBox(width: 12),
      _statPill(
          'Samples', '${_raw.length}', Icons.data_usage, AppColors.primary),
    ]);
  }

  Widget _statPill(String label, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
                color: Colors.black.withValues(alpha: 0.06), blurRadius: 8),
          ],
        ),
        child: Row(children: [
          Icon(icon, color: color, size: 22),
          const SizedBox(width: 10),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF7A8BA0))),
            Text(value,
                style: TextStyle(
                    fontSize: 20, fontWeight: FontWeight.bold, color: color)),
          ]),
        ]),
      ),
    );
  }

  Widget _reportCard() {
    final r = _report!;

    if (r.containsKey('error')) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.danger.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
        ),
        child: Row(children: [
          Icon(Icons.error_outline, color: AppColors.danger),
          const SizedBox(width: 12),
          Expanded(
              child:
                  Text(r['error'], style: TextStyle(color: AppColors.danger))),
        ]),
      );
    }

    final bpm = r['bpm'] as int;
    final hrv = r['hrv'] as int;
    final spo2 = r['spo2'] as int;
    final bpmZone = r['bpmZone'] as String;
    final bpmColor = r['bpmColor'] as Color;
    final stress = r['stress'] as String;
    final stressColor = r['stressColor'] as Color;
    final peaks = r['peaks'] as int;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.07),
              blurRadius: 12,
              offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(Icons.assignment_turned_in, color: AppColors.accent),
            const SizedBox(width: 8),
            const Text('Vitals Report',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
            const Spacer(),
            Text('${r['samples']} samples • $peaks peaks',
                style: const TextStyle(fontSize: 11, color: Color(0xFF7A8BA0))),
          ]),
          const Divider(height: 24),
          _reportRow(
            icon: Icons.favorite,
            iconColor: Colors.redAccent,
            label: 'Heart Rate',
            value: '$bpm BPM',
            sub: bpmZone,
            valueColor: bpmColor,
          ),
          const SizedBox(height: 14),
          _reportRow(
            icon: Icons.air,
            iconColor: Colors.blue,
            label: 'SpO₂ (est.)',
            value: '$spo2%',
            sub: spo2 >= 95
                ? 'Normal'
                : spo2 >= 90
                    ? 'Low'
                    : 'Very Low',
            valueColor: spo2 >= 95 ? AppColors.accent : AppColors.danger,
          ),
          const SizedBox(height: 14),
          _reportRow(
            icon: Icons.timeline,
            iconColor: Colors.purple,
            label: 'HRV (RMSSD)',
            value: '$hrv ms',
            sub: hrv > 50
                ? 'Excellent'
                : hrv > 20
                    ? 'Good'
                    : 'Low',
            valueColor: hrv > 20 ? AppColors.accent : AppColors.danger,
          ),
          const SizedBox(height: 14),
          _reportRow(
            icon: Icons.self_improvement,
            iconColor: stressColor,
            label: 'Stress Level',
            value: stress,
            sub: 'Derived from HRV',
            valueColor: stressColor,
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
              style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  padding: const EdgeInsets.symmetric(vertical: 12)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _reportRow({
    required IconData icon,
    required Color iconColor,
    required String label,
    required String value,
    required String sub,
    required Color valueColor,
  }) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label,
              style: const TextStyle(fontSize: 12, color: Color(0xFF7A8BA0))),
          Text(sub,
              style: const TextStyle(fontSize: 11, color: Color(0xFFB0BEC5))),
        ]),
      ),
      Text(value,
          style: TextStyle(
              fontSize: 18, fontWeight: FontWeight.bold, color: valueColor)),
    ]);
  }
}

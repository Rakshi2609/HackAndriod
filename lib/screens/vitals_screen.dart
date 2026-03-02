import 'dart:async';
import 'dart:math';

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class VitalsScreen extends StatefulWidget {
  const VitalsScreen({super.key});

  @override
  State<VitalsScreen> createState() => _VitalsScreenState();
}

class _VitalsScreenState extends State<VitalsScreen> {
  CameraController? _controller;
  bool _scanning = false;
  bool _torchOn = false;

  // store timestamped brightness samples
  final List<Map<String, dynamic>> _samples = [];
  Timer? _bpmTimer;
  Timer? _collectionTimer;
  int _bpm = 0;
  int _elapsed = 0;
  Map<String, dynamic>? _lastReport;

  @override
  void dispose() {
    _bpmTimer?.cancel();
    _stopCamera();
    super.dispose();
  }

  Future<void> _initCamera() async {
    if (kIsWeb) return;
    try {
      final cams = await availableCameras();
      // prefer back camera (with flash)
      CameraDescription? cam = cams.firstWhere(
          (c) => c.lensDirection == CameraLensDirection.back,
          orElse: () =>
              cams.isNotEmpty ? cams.first : throw StateError('No camera'));

      _controller = CameraController(
        cam,
        ResolutionPreset.low,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.yuv420,
      );
      await _controller!.initialize();
    } catch (e) {
      _controller = null;
    }
  }

  Future<void> _startScan() async {
    if (kIsWeb) return;
    if (_controller == null) await _initCamera();
    if (_controller == null) return;

    try {
      await _controller!.setFlashMode(FlashMode.torch);
      _torchOn = true;
    } catch (_) {
      _torchOn = false;
    }

    await _controller!.startImageStream(_processCameraImage);
    _scanning = true;

    // start a 60s collection window — show elapsed and finalize after 60s
    _elapsed = 0;
    _bpmTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsed++;
      // lightweight interim estimate to update UI while collecting
      _computeBPM();
      setState(() {});
    });
    _collectionTimer = Timer(const Duration(seconds: 60), () {
      _finalizeBPM();
    });
    setState(() {});
  }

  Future<void> _stopCamera() async {
    try {
      _bpmTimer?.cancel();
      _collectionTimer?.cancel();
      if (_controller != null) {
        await _controller!.stopImageStream();
        try {
          await _controller!.setFlashMode(FlashMode.off);
        } catch (_) {}
        await _controller!.dispose();
      }
    } catch (_) {}
    _controller = null;
    _scanning = false;
    _torchOn = false;
    _elapsed = 0;
    _samples.clear();
    _bpm = 0;
    setState(() {});
  }

  void _processCameraImage(CameraImage image) {
    // Use Y plane (luma) as proxy for brightness changes caused by blood volume.
    try {
      final plane = image.planes.first;
      final bytes = plane.bytes;
      if (bytes.isEmpty) return;
      int sum = 0;
      for (var i = 0; i < bytes.length; i += max(1, bytes.length ~/ 200)) {
        sum += bytes[i];
      }
      final avg =
          sum / max(1, (bytes.length / max(1, bytes.length ~/ 200)).floor());
      final t = DateTime.now().millisecondsSinceEpoch.toDouble();
      _samples.add({'t': t, 'v': avg});
      // keep last ~12 seconds of data (fps ~15 -> ~180 samples)
      final cutoff = t - 12000;
      while (_samples.isNotEmpty && (_samples.first['t'] as double) < cutoff) {
        _samples.removeAt(0);
      }
    } catch (_) {}
  }

  void _computeBPM() {
    if (_samples.length < 10) return;
    final values = _samples.map((e) => (e['v'] as num).toDouble()).toList();
    // Smooth with moving average window (5)
    final smooth = <double>[];
    for (var i = 0; i < values.length; i++) {
      final window = <double>[];
      for (var j = max(0, i - 2); j <= min(values.length - 1, i + 2); j++) {
        window.add(values[j]);
      }
      smooth.add(window.reduce((a, b) => a + b) / window.length);
    }
    final mean = smooth.reduce((a, b) => a + b) / smooth.length;
    final sq = smooth.map((v) => pow(v - mean, 2));
    final variance = sq.reduce((a, b) => a + b) / smooth.length;
    final std = sqrt(variance);

    final peaks = <double>[];
    for (var i = 1; i < smooth.length - 1; i++) {
      final v = smooth[i];
      if (v > smooth[i - 1] && v > smooth[i + 1] && v > mean + std * 0.5) {
        peaks.add(_samples[i]['t'] as double);
      }
    }
    if (peaks.length < 2) return;
    final intervals = <double>[];
    for (var i = 1; i < peaks.length; i++) {
      intervals.add((peaks[i] - peaks[i - 1]) / 1000.0);
    }
    final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
    final bpm = (60.0 / avgInterval).round();
    if (bpm > 30 && bpm < 200) {
      _bpm = bpm;
    }
  }

  void _finalizeBPM() {
    if (_samples.length < 40) {
      _lastReport = {
        'bpm': null,
        'message': 'Insufficient data collected. Try again (hold device steady with torch).'
      };
      _stopCamera();
      setState(() {});
      return;
    }

    final values = _samples.map((e) => (e['v'] as num).toDouble()).toList();
    // moving average smoothing (window 5)
    final smooth = <double>[];
    for (var i = 0; i < values.length; i++) {
      final window = <double>[];
      for (var j = max(0, i - 2); j <= min(values.length - 1, i + 2); j++) {
        window.add(values[j]);
      }
      smooth.add(window.reduce((a, b) => a + b) / window.length);
    }

    final mean = smooth.reduce((a, b) => a + b) / smooth.length;
    final sq = smooth.map((v) => pow(v - mean, 2));
    final variance = sq.reduce((a, b) => a + b) / smooth.length;
    final std = sqrt(variance);

    final peaks = <double>[];
    for (var i = 1; i < smooth.length - 1; i++) {
      final v = smooth[i];
      if (v > smooth[i - 1] && v > smooth[i + 1] && v > mean + std * 0.5) {
        peaks.add(_samples[i]['t'] as double);
      }
    }

    if (peaks.length < 20) {
      _lastReport = {
        'bpm': null,
        'message': 'Could not reliably detect heartbeat peaks. Try again with steadier placement and torch on.'
      };
      _stopCamera();
      setState(() {});
      return;
    }

    final intervals = <double>[];
    for (var i = 1; i < peaks.length; i++) intervals.add((peaks[i] - peaks[i - 1]) / 1000.0);
    intervals.sort();
    final medianInterval = intervals[intervals.length ~/ 2];
    final bpm = (60.0 / medianInterval).round();
    final confidence = (intervals.length >= 20) ? (min(100, (intervals.length / 1.5).round())) : intervals.length;

    _lastReport = {
      'bpm': (bpm > 30 && bpm < 200) ? bpm : null,
      'confidence': confidence,
      'peaks': peaks.length,
      'message': (bpm > 30 && bpm < 200) ? 'OK' : 'Out of range'
    };

    _stopCamera();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    if (kIsWeb) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(mainAxisSize: MainAxisSize.min, children: const [
            Icon(Icons.warning_amber_rounded, size: 48, color: Colors.orange),
            SizedBox(height: 12),
            Text('Vitals scanner is not supported on Web.',
                style: TextStyle(fontSize: 16)),
            SizedBox(height: 8),
            Text(
                'Open the app on a mobile device with a rear camera and torch for the best results.'),
          ]),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                    color: AppColors.primary.withOpacity(0.04), blurRadius: 10)
              ]),
          child: Column(children: [
            const Text('Vitals Scanner',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
                'Hold the phone with the rear camera against the left side of the chest. Turn on torch for better readings.'),
            const SizedBox(height: 12),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              ElevatedButton.icon(
                onPressed: _scanning
                    ? null
                    : () async {
                        await _startScan();
                      },
                icon: const Icon(Icons.play_arrow),
                label: const Text('Start'),
              ),
              const SizedBox(width: 12),
              ElevatedButton.icon(
                onPressed: _scanning
                    ? () async {
                        await _stopCamera();
                      }
                    : null,
                icon: const Icon(Icons.stop),
                label: const Text('Stop'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
              ),
            ]),
            const SizedBox(height: 12),
            if (_scanning)
              Column(children: [
                Text('Collecting samples: ${_elapsed}s / 60s', style: const TextStyle(fontSize: 16)),
                const SizedBox(height: 8),
                Text('Interim BPM: ${_bpm == 0 ? "—" : _bpm}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Samples: ${_samples.length} · Torch: ${_torchOn ? "On" : "Off"}'),
              ])
            else
              Column(children: [
                Text('Estimated BPM: ${_lastReport != null ? (_lastReport!['bpm'] ?? "—") : (_bpm == 0 ? "—" : _bpm)}',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Samples: ${_samples.length} · Torch: ${_torchOn ? "On" : "Off"}'),
                const SizedBox(height: 8),
                if (_lastReport != null)
                  Container(
                    margin: const EdgeInsets.only(top: 8),
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Column(children: [
                      Text('Last report: ${_lastReport!['bpm'] ?? "—"} BPM', style: const TextStyle(fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text('${_lastReport!['message'] ?? ''}'),
                      if (_lastReport!['confidence'] != null)
                        Text('Confidence: ${_lastReport!['confidence']}% • Peaks: ${_lastReport!['peaks'] ?? 0}'),
                    ]),
                  ),
              ]),
              ]),
          ]),
        ),
      ]),
    );
  }
}

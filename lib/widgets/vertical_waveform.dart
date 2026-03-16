import 'package:flutter/material.dart';

/// Displays a vertical waveform with optional live gain updates via ValueNotifier.
/// 
/// When [gainNotifier] is provided, the waveform repaints on each notifier
/// change WITHOUT any widget rebuild. Uses canvas.scale for zero-cost GPU scaling.
class VerticalWaveform extends StatefulWidget {
  final List<List<double>>? data;
  final Color color;
  final double width;
  final double progress;
  final double gain; // Fallback gain when gainNotifier is null
  final ValueNotifier<double>? gainNotifier; // Live gain from fader drag

  const VerticalWaveform({
    super.key,
    this.data,
    this.color = Colors.cyanAccent,
    this.width = 40,
    this.progress = 0.0,
    this.gain = 1.0,
    this.gainNotifier,
  });

  @override
  State<VerticalWaveform> createState() => _VerticalWaveformState();
}

class _VerticalWaveformState extends State<VerticalWaveform> {
  // Cached base paths (gain=1.0) — rebuilt only when data changes
  List<_ChannelPathInfo>? _cachedChannels;
  List<List<double>>? _lastData;
  Size? _lastSize;

  void _rebuildCache(double w, double h) {
    final data = widget.data;
    if (data == null || data.isEmpty) {
      _cachedChannels = null;
      return;
    }

    _lastData = data;
    _lastSize = Size(w, h);
    _cachedChannels = [];

    bool isStereo = data.length > 1;
    if (!isStereo) {
      _cachedChannels!.add(_buildChannelPath(data[0], w / 2, w / 2, h));
    } else {
      _cachedChannels!.add(_buildChannelPath(data[0], w * 0.25, w * 0.25, h));
      _cachedChannels!.add(_buildChannelPath(data[1], w * 0.75, w * 0.25, h));
    }
  }

  _ChannelPathInfo _buildChannelPath(List<double> channelData, double centerX, double maxWidth, double h) {
    int points = channelData.length;
    if (points < 2) return _ChannelPathInfo(Path(), centerX);

    // Downsample if needed
    final int maxPoints = h.toInt().clamp(50, 500);
    List<double> displayData;
    if (points > maxPoints) {
      displayData = List<double>.filled(maxPoints, 0.0);
      double ratio = points / maxPoints;
      for (int i = 0; i < maxPoints; i++) {
        int start = (i * ratio).floor();
        int end = ((i + 1) * ratio).floor().clamp(start + 1, points);
        double maxVal = 0.0;
        for (int j = start; j < end; j++) {
          if (channelData[j] > maxVal) maxVal = channelData[j];
        }
        displayData[i] = maxVal;
      }
    } else {
      displayData = channelData;
    }

    int displayPoints = displayData.length;
    double stepY = h / displayPoints;
    final Path path = Path();

    // Left side (bottom to top) — at gain=1.0 (no gain baked in)
    for (int i = 0; i < displayPoints; i++) {
      double val = displayData[i];
      double waveWidth = val * (maxWidth * 0.9);
      double y = h - (i * stepY);
      if (i == 0) path.moveTo(centerX - waveWidth, y);
      else path.lineTo(centerX - waveWidth, y);
    }

    path.lineTo(centerX, 0);

    // Right side (reverse)
    for (int i = displayPoints - 1; i >= 0; i--) {
      double val = displayData[i];
      double waveWidth = val * (maxWidth * 0.9);
      double y = h - (i * stepY);
      path.lineTo(centerX + waveWidth, y);
    }

    path.close();
    return _ChannelPathInfo(path, centerX);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.data == null || widget.data!.isEmpty) return SizedBox(width: widget.width);

    return SizedBox(
      width: widget.width,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final w = constraints.maxWidth;
          final h = constraints.maxHeight;

          // Rebuild cache when data or size changes
          if (!identical(_lastData, widget.data) || _lastSize != Size(w, h)) {
            _rebuildCache(w, h);
          }

          return CustomPaint(
            size: Size(w, h),
            painter: _ScaledWaveformPainter(
              channels: _cachedChannels ?? [],
              color: widget.color,
              progress: widget.progress,
              fallbackGain: widget.gain,
              isStereo: (widget.data?.length ?? 0) > 1,
              width: w,
              // Pass notifier — painter reads .value in paint() for live updates
              gainNotifier: widget.gainNotifier,
            ),
          );
        },
      ),
    );
  }
}

class _ChannelPathInfo {
  final Path path;
  final double centerX;
  _ChannelPathInfo(this.path, this.centerX);
}

class _ScaledWaveformPainter extends CustomPainter {
  final List<_ChannelPathInfo> channels;
  final Color color;
  final double progress;
  final double fallbackGain;
  final bool isStereo;
  final double width;
  final ValueNotifier<double>? gainNotifier;

  _ScaledWaveformPainter({
    required this.channels,
    required this.color,
    required this.progress,
    required this.fallbackGain,
    required this.isStereo,
    required this.width,
    this.gainNotifier,
  }) : super(repaint: gainNotifier); // Triggers repaint when notifier fires

  /// Read gain LIVE from notifier during paint, not from constructor snapshot
  double get _currentGain => gainNotifier?.value ?? fallbackGain;

  @override
  void paint(Canvas canvas, Size size) {
    if (channels.isEmpty) return;

    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;

    final double h = size.height;
    final double gain = _currentGain; // Live value!

    // Draw each channel with gain applied via canvas.scale (GPU-level, zero cost)
    for (final channel in channels) {
      canvas.save();
      canvas.translate(channel.centerX, 0);
      canvas.scale(gain, 1.0);
      canvas.translate(-channel.centerX, 0);
      canvas.drawPath(channel.path, paint);
      canvas.restore();
    }

    // Center divider for stereo
    if (isStereo) {
      canvas.drawLine(
        Offset(width / 2, 0),
        Offset(width / 2, h),
        Paint()..color = Colors.white10..strokeWidth = 1,
      );
    }

    // Playhead
    if (progress > 0) {
      final playHeadY = h - (progress * h);
      canvas.drawLine(
        Offset(0, playHeadY),
        Offset(width, playHeadY),
        Paint()..color = Colors.white..strokeWidth = 2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScaledWaveformPainter oldDelegate) {
    return oldDelegate.progress != progress ||
           oldDelegate.fallbackGain != fallbackGain ||
           oldDelegate.color != color ||
           oldDelegate.channels != channels;
  }
}

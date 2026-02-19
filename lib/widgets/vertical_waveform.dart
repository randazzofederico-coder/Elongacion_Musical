import 'package:flutter/material.dart';

class VerticalWaveform extends StatelessWidget {
  final List<List<double>>? data; // [Channel 0, Channel 1?]
  final Color color;
  final double width;
  final double progress; // 0.0 to 1.0 (Playhead location from Bottom to Top)
  final double gain; // 0.0 to 1.0 (Scaling factor for width)

  const VerticalWaveform({
    super.key,
    this.data,
    this.color = Colors.cyanAccent,
    this.width = 40,
    this.progress = 0.0,
    this.gain = 1.0,
  });

  @override
  Widget build(BuildContext context) {
    if (data == null || data!.isEmpty) return SizedBox(width: width);

    return SizedBox(
      width: width,
      child: CustomPaint(
        painter: _WaveformPainter(data: data!, color: color, progress: progress, gain: gain),
      ),
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<List<double>> data;
  final Color color;
  final double progress;
  final double gain;

  _WaveformPainter({required this.data, required this.color, required this.progress, required this.gain});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;
    
    final Paint paint = Paint()
      ..color = color.withValues(alpha: 0.6)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.fill;

    final double w = size.width;
    final double h = size.height;
    
    bool isStereo = data.length > 1;
    
    if (!isStereo) {
       _drawChannel(canvas, data[0], w / 2, w / 2, h, paint);
    } else {
       _drawChannel(canvas, data[0], w * 0.25, w * 0.25, h, paint);
       _drawChannel(canvas, data[1], w * 0.75, w * 0.25, h, paint);
       
       canvas.drawLine(
         Offset(w/2, 0), 
         Offset(w/2, h), 
         Paint()..color = Colors.white10..strokeWidth = 1
       );
    }
    
    // Draw Playhead
    final playHeadY = h - (progress * h);
    if (progress > 0) {
      canvas.drawLine(
        Offset(0, playHeadY),
        Offset(w, playHeadY),
        Paint()..color = Colors.white..strokeWidth = 2
      );
    }
  }
  
  void _drawChannel(Canvas canvas, List<double> channelData, double centerX, double maxWidth, double h, Paint paint) {
    int points = channelData.length;
    if (points < 2) return;
    
    double stepY = h / points;
    
    final Path path = Path();
    path.moveTo(centerX, h);
    
    // Bottom to Top -> (i) is y descending
    // 0 -> h
    // max -> 0
    
    // Left Side
    for (int i = 0; i < points; i++) {
       double val = channelData[i];
       double waveWidth = val * (maxWidth * 0.9) * gain;
       double y = h - (i * stepY);
       if (i == 0) path.moveTo(centerX - waveWidth, y);
       else path.lineTo(centerX - waveWidth, y);
    }
    
    // Top
    path.lineTo(centerX, 0);
    
    // Right Side (Reverse to close loop cleanly)
    for (int i = points - 1; i >= 0; i--) {
       double val = channelData[i];
       double waveWidth = val * (maxWidth * 0.9) * gain;
       double y = h - (i * stepY);
       path.lineTo(centerX + waveWidth, y);
    }
    
    path.close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _WaveformPainter oldDelegate) {
     return true; 
  }
}

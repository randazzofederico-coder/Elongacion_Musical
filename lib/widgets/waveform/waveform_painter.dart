import 'package:flutter/material.dart';

class WaveformPainter extends CustomPainter {
  final List<List<double>>? waveformData;
  final Duration position;
  final Duration duration;
  final Color color;
  final Color backgroundColor;
  final double strokeWidth;
  final double gain;
  
  // Loops
  final bool isLoopEnabled;
  final Duration loopStart;
  final Duration loopEnd;

  WaveformPainter({
    required this.waveformData,
    required this.position,
    required this.duration,
    required this.color,
    this.backgroundColor = Colors.black26,
    this.strokeWidth = 1.0,
    this.gain = 1.0,
    this.isLoopEnabled = false,
    this.loopStart = Duration.zero,
    this.loopEnd = Duration.zero,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 0. Draw Background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);
    
    if (waveformData == null || waveformData!.isEmpty) return;

    final w = size.width;
    final h = size.height;
    
    // 0.5 Loop Region Highlight
    if (isLoopEnabled && duration.inMilliseconds > 0) {
       double startX = (loopStart.inMilliseconds / duration.inMilliseconds) * w;
       double endX = (loopEnd.inMilliseconds / duration.inMilliseconds) * w;
       
       if (endX > startX) {
           final loopPaint = Paint()..color = Colors.white.withValues(alpha: 0.1);
           canvas.drawRect(Rect.fromLTRB(startX, 0, endX, h), loopPaint);
           
           // Draw markers
           final markerPaint = Paint()..color = Colors.amber..strokeWidth = 1;
           canvas.drawLine(Offset(startX, 0), Offset(startX, h), markerPaint);
           canvas.drawLine(Offset(endX, 0), Offset(endX, h), markerPaint);
           
           // Handles?
           // The "Handles" are visual cues. We can draw small triangles.
           final handlePath = Path();
           // Start Handle (Top arrow down)
           handlePath.moveTo(startX, 0);
           handlePath.lineTo(startX + 6, 0);
           handlePath.lineTo(startX, 6);
           handlePath.close();
           
           canvas.drawPath(handlePath, Paint()..color = Colors.amber);
           
           final handlePathEnd = Path();
           handlePathEnd.moveTo(endX, h);
           handlePathEnd.lineTo(endX - 6, h);
           handlePathEnd.lineTo(endX, h - 6);
           handlePathEnd.close();
           canvas.drawPath(handlePathEnd, Paint()..color = Colors.amber);
       }
    }

    final wavePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.fill; // Optimized for path

    final bool isStereo = waveformData!.length > 1;
    
    if (!isStereo) {
       _drawChannel(canvas, waveformData![0], 0, h, w, wavePaint);
    } else {
       _drawChannel(canvas, waveformData![0], 0, h / 2, w, wavePaint);
       _drawChannel(canvas, waveformData![1], h / 2, h / 2, w, wavePaint);
       
       // Center Line
       canvas.drawLine(Offset(0, h/2), Offset(w, h/2), Paint()..color = Colors.white10);
    }

    // Playhead
    if (duration.inMilliseconds > 0) {
      final double x = (position.inMilliseconds / duration.inMilliseconds) * w;
      final headPaint = Paint()..color = Colors.white..strokeWidth = 2; // Thicker playhead
      canvas.drawLine(Offset(x, 0), Offset(x, h), headPaint);
    }
  }
  
  void _drawChannel(Canvas canvas, List<double> data, double topY, double height, double width, Paint paint) {
     int points = data.length;
     if (points == 0) return;
     
     // Optimization: Don't draw more pixels than width?
     // We have downsampled data already?
     // Assume data matches reasonable resolution.
     
     double stepX = width / points;
     double midY = topY + height / 2;
     
     final Path path = Path();
     path.moveTo(0, midY);
     
     // Top edge
     for (int i = 0; i < points; i++) {
        double val = data[i] * gain; 
        if (val > 1.0) val = 1.0;
        
        double x = i * stepX;
        double y = midY - (val * height * 0.45); // Leave 10% gap total
        path.lineTo(x, y);
     }
     
     // Bottom edge (reverse)
     for (int i = points - 1; i >= 0; i--) {
        double val = data[i] * gain;
        if (val > 1.0) val = 1.0;

        double x = i * stepX;
        double y = midY + (val * height * 0.45);
        path.lineTo(x, y);
     }
     
     path.close();
     canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant WaveformPainter oldDelegate) {
     return oldDelegate.position != position ||
            oldDelegate.waveformData != waveformData ||
            oldDelegate.duration != duration || 
            oldDelegate.isLoopEnabled != isLoopEnabled ||
            oldDelegate.loopStart != loopStart ||
            oldDelegate.loopEnd != loopEnd;
  }
}

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

  // Zoom
  final double zoomLevel;
  final double scrollOffset;

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
    this.zoomLevel = 1.0,
    this.scrollOffset = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // 0. Draw Background
    final bgPaint = Paint()..color = backgroundColor;
    canvas.drawRect(Offset.zero & size, bgPaint);
    
    if (waveformData == null || waveformData!.isEmpty) return;

    final w = size.width;
    final h = size.height;
    
    final virtualWidth = w * zoomLevel;
    
    // 0.5 Loop Region Highlight
    if (isLoopEnabled && duration.inMilliseconds > 0) {
       double startAbsoluteX = (loopStart.inMilliseconds / duration.inMilliseconds) * virtualWidth;
       double endAbsoluteX = (loopEnd.inMilliseconds / duration.inMilliseconds) * virtualWidth;
       
       double startX = startAbsoluteX - scrollOffset;
       double endX = endAbsoluteX - scrollOffset;
       
       if (endX > startX) {
           final double drawStartX = startX.clamp(0.0, w);
           final double drawEndX = endX.clamp(0.0, w);
           if (drawEndX > drawStartX) {
              final loopPaint = Paint()..color = Colors.white.withValues(alpha: 0.1);
              canvas.drawRect(Rect.fromLTRB(drawStartX, 0, drawEndX, h), loopPaint);
           }
           
           // Draw markers only if visible
           final markerPaint = Paint()..color = Colors.amber..strokeWidth = 1;
           if (startX >= 0 && startX <= w) {
               canvas.drawLine(Offset(startX, 0), Offset(startX, h), markerPaint);
               final handlePath = Path();
               handlePath.moveTo(startX, 0);
               handlePath.lineTo(startX + 6, 0);
               handlePath.lineTo(startX, 6);
               handlePath.close();
               canvas.drawPath(handlePath, Paint()..color = Colors.amber);
           }
           if (endX >= 0 && endX <= w) {
               canvas.drawLine(Offset(endX, 0), Offset(endX, h), markerPaint);
               final handlePathEnd = Path();
               handlePathEnd.moveTo(endX, h);
               handlePathEnd.lineTo(endX - 6, h);
               handlePathEnd.lineTo(endX, h - 6);
               handlePathEnd.close();
               canvas.drawPath(handlePathEnd, Paint()..color = Colors.amber);
           }
       }
    }

    final wavePaint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.fill; // Optimized for path

    final bool isStereo = waveformData!.length > 1;
    
    if (!isStereo) {
       _drawChannel(canvas, waveformData![0], 0, h, virtualWidth, scrollOffset, wavePaint);
    } else {
       _drawChannel(canvas, waveformData![0], 0, h / 2, virtualWidth, scrollOffset, wavePaint);
       _drawChannel(canvas, waveformData![1], h / 2, h / 2, virtualWidth, scrollOffset, wavePaint);
       
       // Center Line
       canvas.drawLine(Offset(0, h/2), Offset(w, h/2), Paint()..color = Colors.white10);
    }

    // Playhead
    if (duration.inMilliseconds > 0) {
      final double absoluteX = (position.inMilliseconds / duration.inMilliseconds) * virtualWidth;
      final double x = absoluteX - scrollOffset;
      if (x >= 0 && x <= w) {
          final headPaint = Paint()..color = Colors.white..strokeWidth = 2; // Thicker playhead
          canvas.drawLine(Offset(x, 0), Offset(x, h), headPaint);
      }
    }
  }
  
  void _drawChannel(Canvas canvas, List<double> data, double topY, double height, double virtualWidth, double scrollOffset, Paint paint) {
     int points = data.length;
     if (points == 0) return;
     
     // Optimization: Don't draw more pixels than width?
     // We have downsampled data already?
     // Assume data matches reasonable resolution.
     
     double stepX = virtualWidth / points;
     double midY = topY + height / 2;
     
     final Path path = Path();
     bool isFirst = true;
     
     // Top edge
     for (int i = 0; i < points; i++) {
        double absoluteX = i * stepX;
        double screenX = absoluteX - scrollOffset;

        // Render culling
        // Calculate the next point's X to see if this segment is at least partially visible
        double nextScreenX = (i+1) * stepX - scrollOffset;
        // Optimization check - if segment is fully out of bounds, skip
        // Note: this assumes screen width is canvas size.width? 
        // We aren't passing screenWidth but it's typically close to safe area
        // Let's just do a simple generous cull to prevent huge paths when zoomed 50x
        if (nextScreenX < -500 || screenX > 5000) continue; // Hacky big cull box

        double val = data[i] * gain; 
        if (val > 1.0) val = 1.0;
        
        double y = midY - (val * height * 0.45); // Leave 10% gap total
        
        if (isFirst) {
           path.moveTo(screenX, midY); 
           isFirst = false;
        }
        path.lineTo(screenX, y);
     }
     
     // Bottom edge (reverse)
     for (int i = points - 1; i >= 0; i--) {
        double absoluteX = i * stepX;
        double screenX = absoluteX - scrollOffset;

        double nextScreenX = (i-1) * stepX - scrollOffset;
        if (screenX < -500 || nextScreenX > 5000) continue; 

        double val = data[i] * gain;
        if (val > 1.0) val = 1.0;

        double y = midY + (val * height * 0.45);
        
         if (isFirst) {
           path.moveTo(screenX, midY); 
           isFirst = false;
        }
        path.lineTo(screenX, y);
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
            oldDelegate.zoomLevel != zoomLevel ||
            oldDelegate.scrollOffset != scrollOffset ||
            oldDelegate.loopStart != loopStart ||
            oldDelegate.loopEnd != loopEnd;
  }
}

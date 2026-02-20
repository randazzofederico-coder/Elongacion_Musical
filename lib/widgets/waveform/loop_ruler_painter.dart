import 'package:flutter/material.dart';

class LoopRulerPainter extends CustomPainter {
  final int bpm;
  final int timeSignatureTop;
  final int preWaitMeasures;
  final int countInMeasures;
  final Duration duration;
  final Duration loopStart;
  final Duration loopEnd;
  final bool isLoopEnabled;
  final double zoomLevel;
  final double scrollOffset;

  LoopRulerPainter({
    required this.bpm,
    required this.timeSignatureTop,
    required this.preWaitMeasures,
    required this.countInMeasures,
    required this.duration,
    required this.loopStart,
    required this.loopEnd,
    required this.isLoopEnabled,
    required this.zoomLevel,
    required this.scrollOffset,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (duration.inMilliseconds == 0 || bpm == 0) return;

    final double msPerBeat = 60000.0 / bpm;
    final double msPerMeasure = msPerBeat * timeSignatureTop;
    final double totalMs = duration.inMilliseconds.toDouble();
    
    final Paint linePaint = Paint()
      ..color = Colors.white24
      ..strokeWidth = 1.0;

    final Paint measurePaint = Paint()
      ..color = Colors.white54
      ..strokeWidth = 2.0;

    final TextPainter textPainter = TextPainter(
      textDirection: TextDirection.ltr,
    );

    int beatIndex = 0;
    final int totalIntroMeasures = preWaitMeasures + countInMeasures;
    
    // Zoom logic
    final double virtualWidth = size.width * zoomLevel;
    // Calculate how many pixels one measure takes on screen
    final double pixelsPerMeasure = (msPerMeasure / totalMs) * virtualWidth;
    
    // Determine level of detail
    int measureLabelStep = 1;
    bool showBeats = true;

    if (pixelsPerMeasure < 30) {
       showBeats = false;
       if (pixelsPerMeasure < 10) measureLabelStep = 8;
       else if (pixelsPerMeasure < 15) measureLabelStep = 4;
       else measureLabelStep = 2;
    }

    for (double timeMs = 0; timeMs <= totalMs; timeMs += msPerBeat) {
      final double absoluteX = (timeMs / totalMs) * virtualWidth;
      final double screenX = absoluteX - scrollOffset;

      // Culling: Don't draw if outside visible screen viewport
      if (screenX < -20 || screenX > size.width + 20) {
         beatIndex++;
         continue;
      }

      final bool isMeasure = (beatIndex % timeSignatureTop) == 0;

      if (isMeasure) {
        final int absoluteMeasureIndex = beatIndex ~/ timeSignatureTop;
        final int displayMeasureNum = absoluteMeasureIndex - totalIntroMeasures + 1;
        bool isNumbered = false;

        // Determine if this measure should have a number
        if (displayMeasureNum > 0) {
           if ((displayMeasureNum - 1) % measureLabelStep == 0) {
              isNumbered = true;
           }
        }

        if (isNumbered) {
            // Draw full measure line
            canvas.drawLine(Offset(screenX, 0), Offset(screenX, size.height), measurePaint);
            
            textPainter.text = TextSpan(
              text: '$displayMeasureNum',
              style: const TextStyle(color: Colors.white70, fontSize: 10, fontWeight: FontWeight.bold),
            );
            textPainter.layout();
            textPainter.paint(canvas, Offset(screenX + 2, 0));
        } else {
            // Draw a smaller measure line since we are zoomed out and it has no number
            canvas.drawLine(Offset(screenX, size.height * 0.4), Offset(screenX, size.height), measurePaint);
        }
      } else if (showBeats) {
        // Draw the beat subdivision line
        canvas.drawLine(Offset(screenX, size.height * 0.5), Offset(screenX, size.height), linePaint);
      }
      
      beatIndex++;
    }

    // Draw loop handles on the ruler
    if (isLoopEnabled && loopEnd > loopStart) {
      final double loopStartAbsoluteX = (loopStart.inMilliseconds / totalMs) * virtualWidth;
      final double loopEndAbsoluteX = (loopEnd.inMilliseconds / totalMs) * virtualWidth;
      
      final double screenStartX = loopStartAbsoluteX - scrollOffset;
      final double screenEndX = loopEndAbsoluteX - scrollOffset;

      final Path startHandle = Path()
        ..moveTo(screenStartX, 0)
        ..lineTo(screenStartX + 8, 0)
        ..lineTo(screenStartX, size.height)
        ..close();

      final Path endHandle = Path()
        ..moveTo(screenEndX, 0)
        ..lineTo(screenEndX - 8, 0)
        ..lineTo(screenEndX, size.height)
        ..close();

      final Paint handlePaint = Paint()..color = Colors.cyanAccent;
      canvas.drawPath(startHandle, handlePaint);
      canvas.drawPath(endHandle, handlePaint);
      
      // Draw highlight between handles on ruler (clamp to screen width to avoid massive rects offscreen)
      final double highlightStartX = screenStartX.clamp(0.0, size.width);
      final double highlightEndX = screenEndX.clamp(0.0, size.width);
      
      if (highlightEndX > highlightStartX) {
        final Rect highlightRect = Rect.fromLTRB(highlightStartX, size.height * 0.8, highlightEndX, size.height);
        canvas.drawRect(highlightRect, Paint()..color = Colors.cyanAccent.withValues(alpha: 0.3));
      }
    }
  }

  @override
  bool shouldRepaint(covariant LoopRulerPainter oldDelegate) {
    return oldDelegate.bpm != bpm ||
           oldDelegate.timeSignatureTop != timeSignatureTop ||
           oldDelegate.preWaitMeasures != preWaitMeasures ||
           oldDelegate.countInMeasures != countInMeasures ||
           oldDelegate.duration != duration ||
           oldDelegate.loopStart != loopStart ||
           oldDelegate.loopEnd != loopEnd ||
           oldDelegate.isLoopEnabled != isLoopEnabled ||
           oldDelegate.zoomLevel != zoomLevel ||
           oldDelegate.scrollOffset != scrollOffset;
  }
}

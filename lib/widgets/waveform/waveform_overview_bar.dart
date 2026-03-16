import 'package:flutter/material.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/widgets/waveform/waveform_painter.dart';

class WaveformOverviewBar extends StatelessWidget {
  final double width;
  final Duration totalDuration;
  final Duration position;
  final double zoomLevel;
  final double scrollOffset;
  final List<List<double>> waveformData;
  final Function(double ratio) onPanRequested;

  const WaveformOverviewBar({
    super.key,
    required this.width,
    required this.totalDuration,
    required this.position,
    required this.zoomLevel,
    required this.scrollOffset,
    required this.waveformData,
    required this.onPanRequested,
  });

  @override
  Widget build(BuildContext context) {
    if (totalDuration.inMilliseconds <= 0 || width <= 0) {
      return const SizedBox.shrink();
    }

    final double height = 18.0;
    
    // Viewport math
    final double virtualWidth = width * zoomLevel;
    final double viewportRatio = (width / virtualWidth).clamp(0.0, 1.0);
    final double maxScroll = virtualWidth - width;
    
    double offsetRatio = 0.0;
    if (maxScroll > 0) {
      offsetRatio = (scrollOffset / virtualWidth).clamp(0.0, 1.0 - viewportRatio);
    }

    return GestureDetector(
      onTapDown: (details) {
         _handleInteraction(details.localPosition.dx);
      },
      onPanUpdate: (details) {
         _handleInteraction(details.localPosition.dx);
      },
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: AppColors.surfaceHighlight(context).withOpacity(0.3),
          borderRadius: BorderRadius.circular(4),
          border: Border.all(color: AppColors.border(context).withOpacity(0.3)),
        ),
        child: Stack(
          children: [
            // Miniature Waveform
            Positioned.fill(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: Opacity(
                  opacity: 0.5,
                  child: CustomPaint(
                    painter: WaveformPainter(
                      waveformData: waveformData,
                      position: position,
                      duration: totalDuration,
                      color: AppColors.accentCyan(context).withOpacity(0.4),
                      playheadColor: AppColors.textPrimary(context),
                      zoomLevel: 1.0, 
                      scrollOffset: 0.0,
                    ),
                  ),
                ),
              ),
            ),
            
            // Viewport Highlight Box
            Positioned(
              left: width * offsetRatio,
              top: 0,
              bottom: 0,
              width: width * viewportRatio,
              child: Container(
                decoration: BoxDecoration(
                  color: AppColors.accentCyan(context).withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                  border: Border.all(
                    color: AppColors.accentCyan(context),
                    width: 1.5,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _handleInteraction(double localX) {
     // Ensure touch is centered on the viewport box when dragging
     final double virtualWidth = width * zoomLevel;
     final double viewportRatio = (width / virtualWidth).clamp(0.0, 1.0);
     
     double targetRatio = (localX / width) - (viewportRatio / 2.0);
     targetRatio = targetRatio.clamp(0.0, 1.0 - viewportRatio);
     
     onPanRequested(targetRatio);
  }
}

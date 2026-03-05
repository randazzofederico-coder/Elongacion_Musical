import 'package:flutter/material.dart';
import 'package:elongacion_musical/widgets/waveform/loop_ruler_painter.dart';
import 'package:elongacion_musical/constants/app_colors.dart';

class LoopRuler extends StatelessWidget {
  final double width;
  final double totalMs;
  final int bpm;
  final int timeSignatureNumerator;
  final int preWaitMeasures;
  final int countInMeasures;
  final Duration duration;
  final Duration loopStart;
  final Duration loopEnd;
  final bool isLoopEnabled;
  final double zoomLevel;
  final double scrollOffset;

  const LoopRuler({
    super.key,
    required this.width,
    required this.totalMs,
    required this.bpm,
    required this.timeSignatureNumerator,
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
  Widget build(BuildContext context) {
    return Container(
      height: 24, // Taller for better touch target
      width: width,
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        border: Border(bottom: BorderSide(color: AppColors.border(context), width: 1.0)),
      ),
      child: ClipRect(
        child: CustomPaint(
          painter: LoopRulerPainter(
            bpm: bpm,
            timeSignatureTop: timeSignatureNumerator,
            preWaitMeasures: preWaitMeasures,
            countInMeasures: countInMeasures,
            duration: duration,
            loopStart: loopStart,
            loopEnd: loopEnd,
            isLoopEnabled: isLoopEnabled,
            zoomLevel: zoomLevel,
            scrollOffset: scrollOffset,
            borderColor: AppColors.border(context),
            textSecondaryColor: AppColors.textSecondary(context),
            textPrimaryColor: AppColors.textPrimary(context),
            accentColor: AppColors.accentCyan(context),
          ),
        ),
      ),
    );
  }
}

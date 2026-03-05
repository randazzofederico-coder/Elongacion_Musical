import 'package:flutter/material.dart';
import 'package:elongacion_musical/constants/app_colors.dart';

class ChannelStripContainer extends StatelessWidget {
  final double width;
  final String label;
  final Color? headerBgColor;
  final Color? headerTextColor;
  
  /// The widget to display in the upper/left waveform section (optional).
  final Widget? waveformArea;
  
  /// The widget to display in the lower/right controls section (faders, knobs, buttons).
  final Widget controlsArea;
  
  final bool isMaster;

  const ChannelStripContainer({
    super.key,
    required this.width,
    required this.label,
    this.waveformArea,
    required this.controlsArea,
    this.headerBgColor,
    this.headerTextColor,
    this.isMaster = false,
  });

  @override
  Widget build(BuildContext context) {
    final double headerHeight = width < 60 ? 28.0 : 36.0;

    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 8), 
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: AppColors.surfaceHighlight(context).withOpacity(0.3),
            offset: const Offset(0, 1),
            blurRadius: 0, 
          )
        ],
      ),
      child: ClipRRect( 
        borderRadius: BorderRadius.circular(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // 1. Header Area
            Container(
              height: headerHeight,
              alignment: Alignment.center,
              color: headerBgColor ?? AppColors.surfaceHighlight(context).withOpacity(0.5), 
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                label.toUpperCase(),
                style: TextStyle(
                  color: headerTextColor ?? AppColors.textPrimary(context).withOpacity(0.8),
                  fontWeight: FontWeight.w900,
                  fontSize: width < 60 ? 10 : 12,
                  letterSpacing: 1.0,
                  fontFamily: isMaster ? null : 'monospace', 
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            
            // 2. Main Area (Row: Waveform + Controls)
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // WAVEFORM AREA (Expanded: flex 2)
                  if (waveformArea != null)
                    Expanded(
                      flex: 2,
                      child: Container(
                        margin: const EdgeInsets.only(left: 4, bottom: 4, top: 4),
                        decoration: BoxDecoration(
                           color: AppColors.faderTrack(context).withOpacity(0.7),
                           borderRadius: BorderRadius.circular(4),
                           border: Border.all(color: AppColors.border(context).withOpacity(0.5)),
                        ),
                        child: waveformArea!,
                      ),
                    ),
                  
                  // CONTROLS AREA (Right, flex 1)
                  Expanded(
                    flex: 1,
                    child: controlsArea,
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 8), // Bottom padding uniformly inside the strip
          ],
        ),
      ),
    );
  }
}

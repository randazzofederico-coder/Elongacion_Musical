import 'package:flutter/material.dart';
import 'package:elongacion_musical/constants/app_colors.dart';

class MasterControl extends StatelessWidget {
  final double currentSpeed;
  final ValueChanged<double> onSpeedChanged;
  final VoidCallback onResetAll;
  final bool isCompact;

  const MasterControl({
    super.key,
    required this.currentSpeed,
    required this.onSpeedChanged,
    required this.onResetAll,
    this.isCompact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: isCompact ? EdgeInsets.zero : const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: isCompact ? const EdgeInsets.symmetric(horizontal: 8) : const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: isCompact ? null : BoxDecoration(
        color: AppColors.surfaceHighlight(context),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: AppColors.border(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  if (!isCompact) const Icon(Icons.speed, color: Colors.grey, size: 16),
                  if (!isCompact) const SizedBox(width: 4),
                  Text(
                    'TEMPO: ${currentSpeed.toStringAsFixed(2)}x',
                    style: TextStyle(
                      fontWeight: FontWeight.bold, 
                      fontSize: isCompact ? 8 : 12, 
                      color: AppColors.textPrimary(context),
                      letterSpacing: 1.0
                    ),
                  ),
                ],
              ),
              Flexible(
                child: TextButton(
                  onPressed: onResetAll,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: const Size(0, 20),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text('RESET', style: TextStyle(fontSize: isCompact ? 8 : 10, color: AppColors.textSecondary(context), fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
          SizedBox(
            height: 24, // Compact slider height
            child: SliderTheme(
              data: SliderTheme.of(context).copyWith(
                activeTrackColor: AppColors.accentCyan(context),
                inactiveTrackColor: AppColors.faderTrack(context),
                thumbColor: AppColors.accentCyan(context),
                overlayColor: AppColors.accentCyan(context).withValues(alpha: 0.1),
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6),
                overlayShape: const RoundSliderOverlayShape(overlayRadius: 12),
              ),
              child: Slider(
                value: currentSpeed,
                min: 0.5,
                max: 1.5,
                onChanged: onSpeedChanged,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

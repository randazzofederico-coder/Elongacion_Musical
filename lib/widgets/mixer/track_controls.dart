import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/widgets/fader_control.dart';
import 'package:elongacion_musical/widgets/knob_control.dart';

class TrackControls extends StatelessWidget {
  final TrackModel track;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;
  final ValueChanged<double> onPanChanged;
  final ValueChanged<double>? onPanChangeEnd;
  final VoidCallback onMuteToggle;
  final VoidCallback onSoloToggle;
  final bool useKnobForVolume;
  final bool showWaveform;

  const TrackControls({
    super.key,
    required this.track,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
    required this.onPanChanged,
    this.onPanChangeEnd,
    required this.onMuteToggle,
    required this.onSoloToggle,
    required this.useKnobForVolume,
    required this.showWaveform,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        // VOLUME CONTROL: Fader (Top)
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0), 
            child: FaderControl(
              volume: track.volume,
              onChanged: onVolumeChanged,
              onChangeEnd: onVolumeChangeEnd,
              color: AppColors.accentCyan(context),
            ),
          ),
        ),
        
        // Bottom Controls Container (Fixed Height to ensure symmetry)
        // Set to 110 to safely contain buttons and native sized knob without overflow
        SizedBox(
          height: 110, 
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // Pan Knob
              KnobControl(
                value: track.pan,
                onChanged: onPanChanged,
                onChangeEnd: onPanChangeEnd,
                label: "PAN",
                min: -1.0,
                max: 1.0,
                zeroAtCenter: true,
                size: 28, // Native layout size instead of Transform.scale!
              ),
              const Spacer(), // Pushes buttons to bottom
              
              // Buttons (Mute / Solo)
              _buildTactileButton(
                context: context,
                label: "M",
                isActive: track.isMuted,
                activeColor: AppColors.accentRed(context),
                onTap: onMuteToggle,
              ),
              const SizedBox(height: 6),
              _buildTactileButton(
                context: context,
                label: "S",
                isActive: track.isSolo,
                activeColor: AppColors.accentAmber(context),
                onTap: onSoloToggle,
              ),
              const SizedBox(height: 4), // Reduced safe margin
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTactileButton({
    required BuildContext context,
    required String label,
    required bool isActive,
    required Color activeColor,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 34, 
        height: 24, 
        decoration: BoxDecoration(
          color: isActive ? activeColor : AppColors.surfaceHighlight(context).withOpacity(0.5),
          borderRadius: BorderRadius.circular(6), 
          border: Border.all(
            color: isActive ? activeColor.withOpacity(0.8) : AppColors.border(context),
            width: 1,
          ),
          boxShadow: kIsWeb ? null : (isActive
              ? [
                  BoxShadow(color: activeColor.withOpacity(0.6), blurRadius: 8, spreadRadius: 1),
                  const BoxShadow(color: Colors.white24, offset: Offset(0, 1), blurRadius: 1), 
                ]
              : [
                  const BoxShadow(color: Colors.black12, offset: Offset(0, 2), blurRadius: 2),
                ]),
        ),
        alignment: Alignment.center,
        child: Text(
          label, 
          style: TextStyle(
            color: isActive ? Colors.white : AppColors.textPrimary(context).withOpacity(0.7), 
            fontWeight: FontWeight.w900, 
            fontSize: 12,
            shadows: kIsWeb ? null : (isActive ? [Shadow(color: Colors.white.withOpacity(0.5), blurRadius: 4)] : []),
          )
        ),
      ),
    );
  }
}

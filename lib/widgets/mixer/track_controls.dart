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
    required this.onMuteToggle,
    required this.onSoloToggle,
    required this.useKnobForVolume,
    required this.showWaveform,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: showWaveform ? const Border(left: BorderSide(color: AppColors.border, width: 1)) : null
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Pan Knob (Top of controls)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Transform.scale(
              scale: 0.8, // Make it slightly smaller
              child: KnobControl(
                value: track.pan,
                onChanged: onPanChanged,
                label: "PAN",
                min: -1.0,
                max: 1.0,
              ),
            ),
          ),
          
          // VOLUME CONTROL: Fader or Knob
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8.0),
              child: useKnobForVolume 
                ? Center(
                    child: Transform.scale(
                       scale: 0.9,
                       child: KnobControl(
                          value: track.volume,
                          onChanged: onVolumeChanged,
                          onChangeEnd: onVolumeChangeEnd,
                          min: 0.0,
                          max: 1.0, 
                          label: "VOL",
                       ),
                    ),
                  )
                : FaderControl(
                    volume: track.volume,
                    onChanged: onVolumeChanged,
                    onChangeEnd: onVolumeChangeEnd,
                  ),
            ),
          ),
          
          // Buttons (Mute / Solo)
           Container(
             padding: const EdgeInsets.only(bottom: 8),
             child: Column(
               children: [
                 // MUTE
                 GestureDetector(
                   onTap: onMuteToggle,
                   child: Container(
                     width: 30, // Compact
                     height: 24,
                     margin: const EdgeInsets.only(bottom: 4),
                     decoration: BoxDecoration(
                       color: track.isMuted ? AppColors.accentRed : AppColors.surfaceHighlight,
                       borderRadius: BorderRadius.circular(3),
                       border: Border.all(color: Colors.black54),
                     ),
                     alignment: Alignment.center,
                     child: const Text("M", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12)),
                   ),
                 ),
                 
                 // SOLO
                 GestureDetector(
                   onTap: onSoloToggle,
                   child: Container(
                     width: 30, // Compact
                     height: 24,
                     decoration: BoxDecoration(
                       color: track.isSolo ? AppColors.accentAmber : AppColors.surfaceHighlight,
                       borderRadius: BorderRadius.circular(3),
                       border: Border.all(color: Colors.black54),
                     ),
                     alignment: Alignment.center,
                     child: Text("S", style: TextStyle(color: track.isSolo ? Colors.black : Colors.white60, fontWeight: FontWeight.bold, fontSize: 12)),
                   ),
                 ),
               ],
             ),
           ),
        ],
      ),
    );
  }
}

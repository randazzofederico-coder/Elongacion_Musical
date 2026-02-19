import 'package:elongacion_musical/widgets/fader_control.dart';
import 'package:elongacion_musical/widgets/vertical_waveform.dart';
import 'package:elongacion_musical/widgets/knob_control.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:flutter/material.dart';

class MasterStrip extends StatelessWidget {
  final List<List<double>> waveformData;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;
  final double progress; // 0.0 to 1.0
  final bool showWaveform;
  final double? width; // Optional override width

  const MasterStrip({
    super.key,
    required this.waveformData,
    required this.volume,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
    required this.progress,
    this.showWaveform = true,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width ?? (showWaveform ? 120 : 80), // Use width if provided, else adaptive default
      margin: const EdgeInsets.only(left: 8),
      decoration: BoxDecoration(
        color: AppColors.surface, // Matches TrackStrip
        border: Border.all(color: AppColors.accentRed, width: 2), // Keep Red border for Master distinction
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header (Top)
          Container(
             height: 24,
             alignment: Alignment.center,
             color: AppColors.accentRed,
             padding: const EdgeInsets.symmetric(horizontal: 4),
             child: Text(
               "MASTER",
               style: TextStyle(
                 color: Colors.white, 
                 fontWeight: FontWeight.bold,
                 fontSize: (width ?? 120) < 50 ? 9 : 12,
                 letterSpacing: (width ?? 120) < 50 ? 0.0 : 1.0,
               ),
               textAlign: TextAlign.center,
               maxLines: 1,
               overflow: TextOverflow.ellipsis,
             ),
          ),
          
          // 2. Main Area
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // WAVEFORM (Expanded)
                if (showWaveform)
                  Expanded(
                    flex: 2,
                    child: Container(
                      color: Colors.black38,
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: VerticalWaveform(
                        data: waveformData,
                        width: double.infinity,
                        color: AppColors.accentRed, 
                        progress: progress,
                        gain: volume, 
                      ),
                    ),
                  ),
                
                // CONTROLS (Right)
                Expanded(
                  flex: 1,
                  child: Container(
                     decoration: BoxDecoration(
                      border: showWaveform ? const Border(left: BorderSide(color: AppColors.border, width: 1)) : null
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // 1. Invisible Pan Knob (Top) for Alignment
                        Visibility(
                          visible: false, 
                          maintainSize: true,
                          maintainAnimation: true,
                          maintainState: true,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Transform.scale(
                              scale: 0.8, 
                              child: KnobControl(
                                value: 0,
                                onChanged: (v){},
                                label: "PAN",
                              ),
                            ),
                          ),
                        ),
                        
                        // 2. Main Fader (Expanded - Same as TrackStrip)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: FaderControl(
                              volume: volume,
                              onChanged: onVolumeChanged,
                              onChangeEnd: onVolumeChangeEnd,
                              color: AppColors.accentRed,
                            ),
                          ),
                        ),
                        
                        // 3. Invisible Buttons (Bottom) for Alignment
                         Visibility(
                           visible: false,
                           maintainSize: true,
                           maintainAnimation: true,
                           maintainState: true,
                           child: Container(
                             padding: const EdgeInsets.only(bottom: 8),
                             child: Column(
                               children: [
                                 // MUTE Placeholder
                                 Container(
                                   width: 30, 
                                   height: 24,
                                   margin: const EdgeInsets.only(bottom: 4),
                                   decoration: BoxDecoration(
                                     borderRadius: BorderRadius.circular(3),
                                     border: Border.all(color: Colors.black54),
                                   ),
                                 ),
                                 
                                 // SOLO Placeholder
                                 Container(
                                   width: 30, 
                                   height: 24,
                                   decoration: BoxDecoration(
                                     borderRadius: BorderRadius.circular(3),
                                     border: Border.all(color: Colors.black54),
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ),
                      ],
                    ),
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

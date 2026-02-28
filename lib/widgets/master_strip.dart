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
                        // 1. Main Fader (Expanded - Same as TrackStrip)
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


                        // 3. Metronome Controls (Bottom)
                        const Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: _MetronomeControls(),
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

class _MetronomeControls extends StatefulWidget {
  const _MetronomeControls({Key? key}) : super(key: key);

  @override
  State<_MetronomeControls> createState() => _MetronomeControlsState();
}

class _MetronomeControlsState extends State<_MetronomeControls> {
  double _vol34 = 0.5;
  bool _isOn34 = false;

  double _vol68 = 0.5;
  bool _isOn68 = false;

  @override
  Widget build(BuildContext context) {
    // In TrackStrip:
    // Pan: ~40px + 8px padding
    // Mute: 22px + 4px margin
    // Solo: 22px
    // Padding bottom: 6px
    // Total approx: 102px
    // Let's make metronome area match exactly with tightly packed knobs
    return Container(
      padding: const EdgeInsets.only(bottom: 6),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Transform.scale(
            scale: 0.65,
            child: KnobControl(
              value: _vol34,
              onChanged: (val) {
                setState(() => _vol34 = val);
              },
              min: 0,
              max: 1,
              label: _isOn34 ? "3/4 ON" : "3/4 OFF",
              labelColor: _isOn34 ? AppColors.accentGreen : AppColors.accentRed,
              onTap: () {
                setState(() => _isOn34 = !_isOn34);
              }
            ),
          ),
          const SizedBox(height: 2), // tighter spacing
          Transform.scale(
            scale: 0.65,
            child: KnobControl(
              value: _vol68,
              onChanged: (val) {
                setState(() => _vol68 = val);
              },
              min: 0,
              max: 1,
              label: _isOn68 ? "6/8 ON" : "6/8 OFF",
              labelColor: _isOn68 ? AppColors.accentGreen : AppColors.accentRed,
              onTap: () {
                setState(() => _isOn68 = !_isOn68);
              }
            ),
          ),
        ],
      ),
    );
  }
}

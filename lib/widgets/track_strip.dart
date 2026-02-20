import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/widgets/vertical_waveform.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/widgets/mixer/track_controls.dart';
import 'package:flutter/material.dart';

class TrackStrip extends StatelessWidget {
  final TrackModel track;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;
  final ValueChanged<double> onPanChanged;
  final VoidCallback onMuteToggle;
  final VoidCallback onSoloToggle;
  final bool isSoloed;
  final double width;
  final bool showWaveform;
  final bool useKnobForVolume;

  const TrackStrip({
    super.key,
    required this.track,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
    required this.onPanChanged,
    required this.onMuteToggle,
    required this.onSoloToggle,
    required this.isSoloed,
    this.width = 100, // Default width
    this.showWaveform = true,
    this.useKnobForVolume = false,
  });

  @override
  Widget build(BuildContext context) {
    // Studio Console Look - Refined V2
    // Full width header, Max Waveform
    
    return ListenableBuilder(
      listenable: track,
      builder: (context, child) {
        return Container(
          width: width, // Dynamic width
          margin: const EdgeInsets.symmetric(horizontal: 1), // Reduced margin
          decoration: BoxDecoration(
            color: AppColors.surface, 
            border: Border.all(color: AppColors.border, width: 1),
            borderRadius: BorderRadius.circular(4),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 1. Track Name (Top - Full Width)
              Container(
                 height: width < 50 ? 18 : 24, // Responsive height
                 alignment: Alignment.center,
                 color: Colors.black45, // Keep semi-transparent for overlay feel
                 padding: const EdgeInsets.symmetric(horizontal: 2),
                 child: Text(
                   track.name.toUpperCase(),
                   style: TextStyle(
                     color: AppColors.textPrimary,
                     fontWeight: FontWeight.bold,
                     fontSize: width < 50 ? 8 : 10,
                     letterSpacing: width < 50 ? 0 : 0.5,
                   ),
                   textAlign: TextAlign.center,
                   maxLines: 1,
                   overflow: TextOverflow.ellipsis,
                 ),
              ),
              
              const Divider(color: AppColors.border, height: 1, thickness: 0.5),
    
              // 2. Main Area (Waveform + Controls)
              Expanded(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // WAVEFORM (Expanded to fill space)
                    if (showWaveform)
                      Expanded(
                        flex: 2,
                        child: Container(
                          color: Colors.black26,
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: VerticalWaveform(
                            data: track.waveformData,
                            width: double.infinity, // Fill available width
                            color: AppColors.accentCyan,
                            gain: track.volume, // Dynamic Width based on Volume
                          ),
                        ),
                      ),
                    
                    // CONTROLS (Right - Slimmer)
                    Expanded(
                      flex: 1,
                      child: TrackControls(
                        track: track,
                        onVolumeChanged: onVolumeChanged,
                        onVolumeChangeEnd: onVolumeChangeEnd,
                        onPanChanged: onPanChanged,
                        onMuteToggle: onMuteToggle,
                        onSoloToggle: onSoloToggle,
                        useKnobForVolume: useKnobForVolume,
                        showWaveform: showWaveform,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          ),
        );
      }
    );
  }
}

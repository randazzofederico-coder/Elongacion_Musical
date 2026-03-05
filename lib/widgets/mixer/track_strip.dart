import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/widgets/vertical_waveform.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/widgets/mixer/track_controls.dart';
import 'package:elongacion_musical/widgets/mixer/channel_strip_container.dart';
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
    this.width = 100, 
    this.showWaveform = true,
    this.useKnobForVolume = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: track,
      builder: (context, child) {
        return ChannelStripContainer(
          width: width,
          label: track.name,
          waveformArea: showWaveform 
              ? VerticalWaveform(
                  data: track.waveformData,
                  width: double.infinity, 
                  color: AppColors.accentCyan(context),
                  gain: track.volume, 
                )
              : null,
          controlsArea: TrackControls(
            track: track,
            onVolumeChanged: onVolumeChanged,
            onVolumeChangeEnd: onVolumeChangeEnd,
            onPanChanged: onPanChanged,
            onMuteToggle: onMuteToggle,
            onSoloToggle: onSoloToggle,
            useKnobForVolume: useKnobForVolume,
            showWaveform: showWaveform,
          ),
        );
      }
    );
  }
}

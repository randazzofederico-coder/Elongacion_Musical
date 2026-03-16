import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/widgets/mixer/track_strip.dart';

class TrackListSection extends StatelessWidget {
  final bool showWaveform;
  final double itemWidth;
  final bool useKnobForVolume;
  
  const TrackListSection({super.key, required this.showWaveform, required this.itemWidth, this.useKnobForVolume = false});

  @override
  Widget build(BuildContext context) {
    return Selector<MixerProvider, List<TrackModel>>(
      selector: (_, mixer) => mixer.tracks,
      shouldRebuild: (prev, next) => prev != next,
      builder: (context, activeTracks, child) {
        if (activeTracks.isEmpty) return const SizedBox.shrink();

        return Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: activeTracks.map((track) {
            final mixer = context.read<MixerProvider>();
            return Expanded(
              child: KeyedSubtree(
                key: ValueKey(track.id),
                child: TrackStrip(
                  width: itemWidth,
                  track: track,
                  showWaveform: showWaveform,
                  useKnobForVolume: useKnobForVolume,
                  // During drag: only update native engine, no TrackModel.notifyListeners
                  onVolumeChanged: (val) => mixer.setTrackVolumeDirect(track.id, val),
                  onVolumeChangeEnd: (val) {
                    // Sync model + save settings
                    mixer.setTrackVolume(track.id, val);
                    mixer.commitTrackVolume();
                  },
                  onPanChanged: (val) => mixer.setTrackPanDirect(track.id, val),
                  onPanChangeEnd: (val) {
                    mixer.setTrackPan(track.id, val);
                    mixer.commitTrackPan(track.id);
                  },
                  onMuteToggle: () => mixer.toggleTrackMute(track.id),
                  onSoloToggle: () => mixer.toggleSolo(track.id),
                  isSoloed: track.isSolo,
                ),
              ),
            );
          }).toList(),
        );
      }
    );
  }
}

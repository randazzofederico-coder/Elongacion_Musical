import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/widgets/track_strip.dart';

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

        return ReorderableListView.builder(
          scrollDirection: Axis.horizontal,
          onReorder: (oldIndex, newIndex) {
             context.read<MixerProvider>().reorderTracks(oldIndex, newIndex);
          },
          buildDefaultDragHandles: false, 
          itemCount: activeTracks.length,
          itemBuilder: (context, index) {
            final track = activeTracks[index];
            final mixer = context.read<MixerProvider>();
            return ReorderableDragStartListener(
              key: ValueKey(track.id),
              index: index,
              child: TrackStrip(
                width: itemWidth,
                track: track,
                showWaveform: showWaveform,
                useKnobForVolume: useKnobForVolume,
                onVolumeChanged: (val) {
                  mixer.setTrackVolume(track.id, val);
                },
                onVolumeChangeEnd: (val) {
                  mixer.commitTrackVolume();
                },
                onPanChanged: (val) {
                  mixer.setTrackPan(track.id, val);
                },
                onMuteToggle: () => mixer.toggleTrackMute(track.id),
                onSoloToggle: () => mixer.toggleSolo(track.id),
                isSoloed: mixer.soloTrackId == track.id,
              ),
            );
          },
        );
      }
    );
  }
}

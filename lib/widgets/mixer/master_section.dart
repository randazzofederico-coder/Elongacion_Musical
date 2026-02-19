import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/widgets/master_strip.dart';

class MasterSection extends StatelessWidget {
  final bool showWaveform;
  final double? width;
  
  const MasterSection({super.key, required this.showWaveform, this.width});

  @override
  Widget build(BuildContext context) {
    final mixer = context.watch<MixerProvider>();
    
    return ListenableBuilder(
      listenable: Listenable.merge(mixer.tracks),
      builder: (context, child) {
        return StreamBuilder<Duration>(
          stream: mixer.positionStream,
          builder: (context, snapshot) {
            final pos = snapshot.data ?? Duration.zero;
            
            return StreamBuilder<Duration?>(
              stream: mixer.durationStream,
              initialData: mixer.duration,
              builder: (context, durationSnap) {
                 final total = durationSnap.data ?? Duration.zero;
                 double progress = 0.0;
                 if (total.inMilliseconds > 0) {
                    progress = pos.inMilliseconds / total.inMilliseconds;
                 }
                 
                 return MasterStrip(
                   waveformData: mixer.masterWaveformData,
                   volume: mixer.masterVolume,
                   onVolumeChanged: (vol) => mixer.setMasterVolume(vol),
                   onVolumeChangeEnd: (_) {}, 
                   progress: progress,
                   showWaveform: showWaveform,
                   width: width,
                 );
              }
            );
          }
        );
      }
    );
  }
}

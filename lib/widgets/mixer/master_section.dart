import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/widgets/mixer/master_strip.dart';

class MasterSection extends StatelessWidget {
  final bool showWaveform;
  final double? width;
  
  const MasterSection({super.key, required this.showWaveform, this.width});

  @override
  Widget build(BuildContext context) {
    return Selector<MixerProvider, ({
      double masterVolume,
      double metronomeVol34,
      double metronomeVol68,
      List<List<double>> waveformData,
    })>(
      selector: (_, m) => (
        masterVolume: m.masterVolume,
        metronomeVol34: m.metronomeVol34,
        metronomeVol68: m.metronomeVol68,
        waveformData: m.masterWaveformData,
      ),
      builder: (context, state, child) {
        final mixer = context.read<MixerProvider>();
        return MasterStrip(
          waveformData: state.waveformData,
          volume: state.masterVolume,
          onVolumeChanged: (vol) => mixer.setMasterVolumeDirect(vol),
          onVolumeChangeEnd: (vol) {
            mixer.setMasterVolume(vol);
            mixer.commitMasterVolume();
          },
          progress: 0.0,
          metronomeVol34: state.metronomeVol34,
          metronomeVol68: state.metronomeVol68,
          onMetronomeChanged: (vol34, vol68) => mixer.setMetronomeVolume(vol34, vol68),
          showWaveform: showWaveform,
          width: width,
        );
      },
    );
  }
}

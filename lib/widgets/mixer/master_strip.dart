import 'package:elongacion_musical/widgets/fader_control.dart';
import 'package:elongacion_musical/widgets/vertical_waveform.dart';
import 'package:elongacion_musical/widgets/knob_control.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/widgets/mixer/channel_strip_container.dart';
import 'package:flutter/material.dart';

class MasterStrip extends StatelessWidget {
  final List<List<double>> waveformData;
  final double volume;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;
  final double progress; 
  final bool showWaveform;
  final double? width; 
  final double metronomeVol34;
  final double metronomeVol68;
  final Function(double vol34, double vol68) onMetronomeChanged;

  const MasterStrip({
    super.key,
    required this.waveformData,
    required this.volume,
    required this.onVolumeChanged,
    required this.onVolumeChangeEnd,
    required this.progress,
    required this.metronomeVol34,
    required this.metronomeVol68,
    required this.onMetronomeChanged,
    this.showWaveform = true,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return ChannelStripContainer(
      width: width ?? (showWaveform ? 120 : 80),
      label: "MASTER",
      isMaster: true,
      headerBgColor: AppColors.accentRed(context).withOpacity(0.15),
      headerTextColor: AppColors.accentRed(context),
      waveformArea: showWaveform 
          ? VerticalWaveform(
              data: waveformData,
              width: double.infinity,
              color: AppColors.waveformMaster(context), 
              progress: progress,
              gain: volume, 
            )
          : null,
      controlsArea: Container(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            // 1. Main Fader
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4.0), 
                child: FaderControl(
                  volume: volume,
                  onChanged: onVolumeChanged,
                  onChangeEnd: onVolumeChangeEnd,
                  color: AppColors.waveformMaster(context),
                ),
              ),
            ),

            // 2. Metronome Controls (Bottom) - Fixed Height Box 
            // Set to 110 to safely match track controls without overflow
            SizedBox(
              height: 110,
              child: _MetronomeControls(
                 vol34: metronomeVol34,
                 vol68: metronomeVol68,
                 onChanged: onMetronomeChanged,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MetronomeControls extends StatefulWidget {
  final double vol34;
  final double vol68;
  final Function(double vol34, double vol68) onChanged;

  const _MetronomeControls({
    Key? key,
    required this.vol34,
    required this.vol68,
    required this.onChanged,
  }) : super(key: key);

  @override
  State<_MetronomeControls> createState() => _MetronomeControlsState();
}

class _MetronomeControlsState extends State<_MetronomeControls> {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 4), // Tiny padding
      child: Column(
        mainAxisSize: MainAxisSize.max, 
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          KnobControl(
            value: widget.vol34,
            onChanged: (val) {
               widget.onChanged(val, widget.vol68);
            },
            min: 0,
            max: 1,
            label: "3/4", 
            labelColor: widget.vol34 > 0 ? AppColors.accentGreen(context) : AppColors.accentRed(context),
            zeroAtCenter: false,
            size: 28, // Native size
          ),
          const Spacer(), // Perfect distribution inside the 110px box
          KnobControl(
            value: widget.vol68,
            onChanged: (val) {
               widget.onChanged(widget.vol34, val);
            },
            min: 0,
            max: 1,
            label: "6/8", 
            labelColor: widget.vol68 > 0 ? AppColors.accentGreen(context) : AppColors.accentRed(context),
            zeroAtCenter: false,
            size: 28, // Native size
          ),
        ],
      ),
    );
  }
}

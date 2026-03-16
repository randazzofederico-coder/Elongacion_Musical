import 'package:elongacion_musical/widgets/fader_control.dart';
import 'package:elongacion_musical/widgets/vertical_waveform.dart';
import 'package:elongacion_musical/widgets/knob_control.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/widgets/mixer/channel_strip_container.dart';
import 'package:flutter/material.dart';

class MasterStrip extends StatefulWidget {
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
  State<MasterStrip> createState() => _MasterStripState();
}

class _MasterStripState extends State<MasterStrip> {
  /// Live gain notifier for master fader → master waveform visual
  late final ValueNotifier<double> _liveGain;

  @override
  void initState() {
    super.initState();
    _liveGain = ValueNotifier(widget.volume);
  }

  @override
  void didUpdateWidget(MasterStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    _liveGain.value = widget.volume;
  }

  @override
  void dispose() {
    _liveGain.dispose();
    super.dispose();
  }

  void _onVolumeChanged(double vol) {
    _liveGain.value = vol; // Instant visual via gainNotifier
    widget.onVolumeChanged(vol); // Audio engine (Direct)
  }

  @override
  Widget build(BuildContext context) {
    return ChannelStripContainer(
      width: widget.width ?? (widget.showWaveform ? 120 : 80),
      label: "MASTER",
      isMaster: true,
      headerBgColor: AppColors.accentRed(context).withOpacity(0.15),
      headerTextColor: AppColors.accentRed(context),
      waveformArea: widget.showWaveform 
          ? VerticalWaveform(
              data: widget.waveformData,
              width: double.infinity,
              color: AppColors.waveformMaster(context), 
              progress: widget.progress,
              gain: widget.volume,
              gainNotifier: _liveGain, // Live gain from master fader drag
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
                  volume: widget.volume,
                  onChanged: _onVolumeChanged,
                  onChangeEnd: widget.onVolumeChangeEnd,
                  color: AppColors.waveformMaster(context),
                ),
              ),
            ),

            // 2. Metronome Controls (Bottom)
            SizedBox(
              height: 110,
              child: _MetronomeControls(
                 vol34: widget.metronomeVol34,
                 vol68: widget.metronomeVol68,
                 onChanged: widget.onMetronomeChanged,
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
      padding: const EdgeInsets.only(bottom: 4),
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
            size: 28,
          ),
          const Spacer(),
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
            size: 28,
          ),
        ],
      ),
    );
  }
}

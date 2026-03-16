import 'package:elongacion_musical/models/track_model.dart';
import 'package:elongacion_musical/widgets/vertical_waveform.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/widgets/mixer/track_controls.dart';
import 'package:elongacion_musical/widgets/mixer/channel_strip_container.dart';
import 'package:flutter/material.dart';

class TrackStrip extends StatefulWidget {
  final TrackModel track;
  final ValueChanged<double> onVolumeChanged;
  final ValueChanged<double> onVolumeChangeEnd;
  final ValueChanged<double> onPanChanged;
  final ValueChanged<double>? onPanChangeEnd;
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
    this.onPanChangeEnd,
    required this.onMuteToggle,
    required this.onSoloToggle,
    required this.isSoloed,
    this.width = 100, 
    this.showWaveform = true,
    this.useKnobForVolume = false,
  });

  @override
  State<TrackStrip> createState() => _TrackStripState();
}

class _TrackStripState extends State<TrackStrip> {
  /// Live gain notifier — written by FaderControl during drag,
  /// read by VerticalWaveform for zero-rebuild repaints.
  late final ValueNotifier<double> _liveGain;

  @override
  void initState() {
    super.initState();
    _liveGain = ValueNotifier(widget.track.volume);
  }

  @override
  void didUpdateWidget(TrackStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync from model when not actively dragging (e.g., on commit)
    _liveGain.value = widget.track.volume;
  }

  @override
  void dispose() {
    _liveGain.dispose();
    super.dispose();
  }

  void _onVolumeChanged(double val) {
    _liveGain.value = val; // Instant visual update via notifier → repaint only
    widget.onVolumeChanged(val); // Audio engine (Direct)
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.track,
      builder: (context, child) {
        return ChannelStripContainer(
          width: widget.width,
          label: widget.track.name,
          waveformArea: widget.showWaveform 
              ? RepaintBoundary(
                  child: VerticalWaveform(
                    data: widget.track.waveformData,
                    width: double.infinity, 
                    color: AppColors.accentCyan(context),
                    gain: widget.track.volume,
                    gainNotifier: _liveGain, // Live gain from fader drag
                  ),
                )
              : null,
          controlsArea: RepaintBoundary(
            child: TrackControls(
              track: widget.track,
              onVolumeChanged: _onVolumeChanged,
              onVolumeChangeEnd: widget.onVolumeChangeEnd,
              onPanChanged: widget.onPanChanged,
              onPanChangeEnd: widget.onPanChangeEnd,
              onMuteToggle: widget.onMuteToggle,
              onSoloToggle: widget.onSoloToggle,
              useKnobForVolume: widget.useKnobForVolume,
              showWaveform: widget.showWaveform,
            ),
          ),
        );
      }
    );
  }
}

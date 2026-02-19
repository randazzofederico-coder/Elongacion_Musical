import 'dart:math';

import 'package:flutter/material.dart';

class SeekBar extends StatelessWidget {
  final Duration duration;
  final Duration position;
  final Duration bufferedPosition;
  final ValueChanged<Duration>? onChanged;
  final ValueChanged<Duration>? onChangeEnd;

  const SeekBar({
    super.key,
    required this.duration,
    required this.position,
    required this.bufferedPosition,
    this.onChanged,
    this.onChangeEnd,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: Colors.cyanAccent,
            inactiveTrackColor: Colors.white10,
            thumbColor: Colors.cyanAccent,
            overlayColor: Colors.cyanAccent.withValues(alpha: 0.1),
            trackHeight: 2.0,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.0),
            overlayShape: const RoundSliderOverlayShape(overlayRadius: 14.0),
          ),
          child: Slider(
            min: 0.0,
            max: duration.inMilliseconds.toDouble(),
            value: min(position.inMilliseconds.toDouble(),
                duration.inMilliseconds.toDouble()),
            onChanged: (value) {
              if (onChanged != null) {
                onChanged!(Duration(milliseconds: value.round()));
              }
            },
            onChangeEnd: (value) {
              if (onChangeEnd != null) {
                onChangeEnd!(Duration(milliseconds: value.round()));
              }
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatDuration(position), 
                style: const TextStyle(fontSize: 10, color: Colors.white54, fontFamily: "monospace")
              ),
              Text(
                _formatDuration(duration), 
                style: const TextStyle(fontSize: 10, color: Colors.white54, fontFamily: "monospace")
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDuration(Duration? duration) {
    if (duration == null) return '--:--';
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

class SeekBarWrapper extends StatefulWidget {
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;
  final ValueChanged<Duration> onSeek;

  const SeekBarWrapper({
    super.key,
    required this.positionStream,
    required this.durationStream,
    required this.onSeek,
  });

  @override
  State<SeekBarWrapper> createState() => _SeekBarWrapperState();
}

class _SeekBarWrapperState extends State<SeekBarWrapper> {
  // To handle dragging without jumping back
  Duration? _dragValue;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<Duration?>(
      stream: widget.durationStream,
      builder: (context, snapshotDuration) {
        final duration = snapshotDuration.data ?? Duration.zero;
        return StreamBuilder<Duration>(
          stream: widget.positionStream,
          builder: (context, snapshotPosition) {
            final position = snapshotPosition.data ?? Duration.zero;
            return SeekBar(
              duration: duration,
              position: _dragValue ?? position,
              bufferedPosition: Duration.zero,
              onChanged: (value) {
                setState(() {
                  _dragValue = value;
                });
              },
              onChangeEnd: (value) {
                widget.onSeek(value);
                _dragValue = null;
              },
            );
          },
        );
      },
    );
  }
}

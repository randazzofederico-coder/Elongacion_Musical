import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/widgets/waveform/waveform_painter.dart';
import 'package:elongacion_musical/widgets/waveform/loop_ruler.dart';
import 'package:elongacion_musical/widgets/waveform/waveform_interaction_controller.dart';

class WaveformSeekBar extends StatefulWidget {
  final Duration duration;
  final Duration position;
  final List<List<double>> waveformData;
  final bool isLoopEnabled;
  final Duration loopStart;
  final Duration loopEnd;
  final ValueChanged<Duration>? onSeek;
  final ValueChanged<bool>? onLoopToggle;
  final Function(Duration start, Duration end)? onLoopRangeChanged;
  final Function(Duration start, Duration end)? onLoopRangeChangeEnd;
  final int? bpm;
  final int? timeSignatureNumerator;
  final int preWaitMeasures;
  final int countInMeasures;

  const WaveformSeekBar({
    super.key,
    required this.duration,
    required this.position,
    required this.waveformData,
    this.isLoopEnabled = false,
    this.loopStart = Duration.zero,
    this.loopEnd = Duration.zero,
    this.onSeek,
    this.onLoopToggle,
    this.onLoopRangeChanged,
    this.onLoopRangeChangeEnd,
    this.bpm,
    this.timeSignatureNumerator,
    this.preWaitMeasures = 0,
    this.countInMeasures = 0,
  });

  @override
  State<WaveformSeekBar> createState() => _WaveformSeekBarState();
}

class _WaveformSeekBarState extends State<WaveformSeekBar> with SingleTickerProviderStateMixin {
  late Ticker _ticker;
  Duration _visualPosition = Duration.zero;
  late WaveformInteractionController _interactionController;

  @override
  void initState() {
    super.initState();
    _visualPosition = widget.position;
    
    _initController();

    _ticker = createTicker((elapsed) {
       _onTick();
    });
  }

  void _initController() {
    _interactionController = WaveformInteractionController(
      duration: widget.duration,
      bpm: widget.bpm,
      timeSignatureNumerator: widget.timeSignatureNumerator,
      isLoopEnabled: widget.isLoopEnabled,
      initialLoopStart: widget.loopStart,
      initialLoopEnd: widget.loopEnd,
      onSeek: widget.onSeek,
      onLoopRangeChanged: widget.onLoopRangeChanged,
      onLoopRangeChangeEnd: widget.onLoopRangeChangeEnd,
    );
  }

  void _onTick() {
     final mixer = context.read<MixerProvider>();
     if (mixer.isPlaying) {
         setState(() {
             _visualPosition = mixer.currentPosition;
         });
     }
  }

  @override
  void dispose() {
    _ticker.dispose();
    _interactionController.dispose();
    super.dispose();
  }
  
  @override
  void didUpdateWidget(WaveformSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    if (widget.position != oldWidget.position && _interactionController.dragPosition == null) {
        final mixer = context.read<MixerProvider>();
        if (!mixer.isPlaying) {
            _visualPosition = widget.position;
        }
    }

    // Update controller properties without recreating it to preserve transient gesture states
    _interactionController.duration = widget.duration;
    _interactionController.bpm = widget.bpm;
    _interactionController.timeSignatureNumerator = widget.timeSignatureNumerator;
    _interactionController.isLoopEnabled = widget.isLoopEnabled;
    _interactionController.initialLoopStart = widget.loopStart;
    _interactionController.initialLoopEnd = widget.loopEnd;
    
    // Update callbacks just in case closures changed
    _interactionController.onSeek = widget.onSeek;
    _interactionController.onLoopRangeChanged = widget.onLoopRangeChanged;
    _interactionController.onLoopRangeChangeEnd = widget.onLoopRangeChangeEnd;
  }

  @override
  Widget build(BuildContext context) {
    final mixer = context.watch<MixerProvider>();
    if (mixer.isPlaying && !_ticker.isActive) {
        _ticker.start();
    } else if (!mixer.isPlaying && _ticker.isActive) {
        _ticker.stop();
        _visualPosition = mixer.currentPosition;
    }
    
    final double totalMilliseconds = widget.duration.inMilliseconds.toDouble();
    
    if (totalMilliseconds <= 0) return const SizedBox(height: 40);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final mediaHeight = MediaQuery.sizeOf(context).height;
        final height = (mediaHeight * 0.12).clamp(40.0, 80.0);

        return ListenableBuilder(
          listenable: _interactionController,
          builder: (context, child) {
            final double currentMilliseconds = _interactionController.dragPosition?.inMilliseconds.toDouble() ?? _visualPosition.inMilliseconds.toDouble();
            
            return Listener(
              onPointerDown: _interactionController.handlePointerDown,
              onPointerUp: _interactionController.handlePointerUp,
              onPointerCancel: _interactionController.handlePointerCancel,
              child: GestureDetector(
                onScaleStart: (details) => _interactionController.handleScaleStart(details, width),
                onScaleUpdate: (details) => _interactionController.handleScaleUpdate(details, width),
                onScaleEnd: _interactionController.handleScaleEnd,
                onTapUp: (details) => _interactionController.handleTap(details, width),
                child: Column(
                  children: [
                    if (widget.bpm != null && widget.bpm! > 0 && widget.timeSignatureNumerator != null && widget.timeSignatureNumerator! > 0)
                      LoopRuler(
                        width: width,
                        totalMs: totalMilliseconds,
                        bpm: widget.bpm!,
                        timeSignatureNumerator: widget.timeSignatureNumerator!,
                        preWaitMeasures: widget.preWaitMeasures,
                        countInMeasures: widget.countInMeasures,
                        duration: widget.duration,
                        loopStart: _interactionController.dragLoopStart ?? widget.loopStart,
                        loopEnd: _interactionController.dragLoopEnd ?? widget.loopEnd,
                        isLoopEnabled: widget.isLoopEnabled,
                        zoomLevel: _interactionController.zoomLevel,
                        scrollOffset: _interactionController.scrollOffset,
                      ),
                      
                    ClipRect(
                      child: Container(
                        height: height,
                        width: width,
                        color: Colors.black26, 
                        child: CustomPaint(
                          painter: WaveformPainter(
                            waveformData: widget.waveformData,
                            position: Duration(milliseconds: currentMilliseconds.toInt()),
                            duration: widget.duration,
                            color: Colors.cyanAccent,
                            isLoopEnabled: widget.isLoopEnabled,
                            loopStart: _interactionController.dragLoopStart ?? widget.loopStart,
                            loopEnd: _interactionController.dragLoopEnd ?? widget.loopEnd,
                            zoomLevel: _interactionController.zoomLevel,
                            scrollOffset: _interactionController.scrollOffset,
                          ),
                        ),
                      ),
                    ),
                    
                    Padding(
                      padding: const EdgeInsets.fromLTRB(8, 2, 8, 0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _formatDuration(Duration(milliseconds: currentMilliseconds.toInt())),
                            style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: "monospace"),
                          ),
                          Text(
                            _formatDuration(widget.duration),
                            style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: "monospace"),
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
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

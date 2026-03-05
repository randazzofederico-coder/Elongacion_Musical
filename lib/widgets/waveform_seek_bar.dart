import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:provider/provider.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/constants/app_colors.dart';
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

    _interactionController.duration = widget.duration;
    _interactionController.bpm = widget.bpm;
    _interactionController.timeSignatureNumerator = widget.timeSignatureNumerator;
    _interactionController.isLoopEnabled = widget.isLoopEnabled;
    _interactionController.initialLoopStart = widget.loopStart;
    _interactionController.initialLoopEnd = widget.loopEnd;
    
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
                    Container(
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), // Perfect 16px visual match with header/transport
                      padding: const EdgeInsets.all(6), // Shared bezel
                      decoration: BoxDecoration(
                        color: AppColors.surface(context), // Base panel color
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                           BoxShadow(
                             color: Colors.black.withOpacity(0.08),
                             blurRadius: 10,
                             offset: const Offset(0, 4),
                           ),
                           BoxShadow(
                             color: AppColors.surfaceHighlight(context).withOpacity(0.3),
                             offset: const Offset(0, 1),
                             blurRadius: 0,
                           )
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (widget.bpm != null && widget.bpm! > 0 && widget.timeSignatureNumerator != null && widget.timeSignatureNumerator! > 0)
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 1.0), // Align exactly with the 1px border of the waveform container below
                              child: LoopRuler(
                                width: width - 34, // 32 for outer margin/padding + 2 for the waveform borders
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
                            ),
                            
                          Container(
                            decoration: BoxDecoration(
                              color: AppColors.faderTrack(context).withOpacity(0.8), // Inset waveform area
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(color: AppColors.border(context).withOpacity(0.5)),
                            ),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(5),
                              child: SizedBox(
                                height: height,
                                width: width - 32, 
                                child: CustomPaint(
                                  painter: WaveformPainter(
                                    waveformData: widget.waveformData,
                                    position: Duration(milliseconds: currentMilliseconds.toInt()),
                                    duration: widget.duration,
                                    color: AppColors.accentCyan(context),
                                    playheadColor: AppColors.textPrimary(context),
                                    isLoopEnabled: widget.isLoopEnabled,
                                    loopStart: _interactionController.dragLoopStart ?? widget.loopStart,
                                    loopEnd: _interactionController.dragLoopEnd ?? widget.loopEnd,
                                    zoomLevel: _interactionController.zoomLevel,
                                    scrollOffset: _interactionController.scrollOffset,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          
                          // Time Labels moved inside the bezel
                          Padding(
                            padding: const EdgeInsets.only(top: 6, left: 4, right: 4),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  _formatDuration(Duration(milliseconds: currentMilliseconds.toInt())),
                                  style: TextStyle(
                                    fontSize: 11, 
                                    color: AppColors.textPrimary(context).withOpacity(0.8), 
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                                Text(
                                  _formatDuration(widget.duration),
                                  style: TextStyle(
                                    fontSize: 11, 
                                    color: AppColors.textPrimary(context).withOpacity(0.5), 
                                    fontWeight: FontWeight.w600,
                                    fontFeatures: const [FontFeature.tabularFigures()],
                                  ),
                                ),
                              ],
                            ),
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

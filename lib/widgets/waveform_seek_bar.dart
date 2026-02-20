
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/widgets/waveform/waveform_painter.dart';
import 'package:elongacion_musical/widgets/waveform/loop_ruler_painter.dart';

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

  // To handle dragging without jumping back
  Duration? _dragPosition;
  bool _isDraggingLoopStart = false;
  bool _isDraggingLoopEnd = false;
  Duration? _dragLoopStart;
  Duration? _dragLoopEnd;

  // Zoom & Pan state
  double _zoomLevel = 1.0;
  double _scrollOffset = 0.0;
  
  double _baseZoomLevel = 1.0;
  double _initialScrollOffset = 0.0;
  Offset _initialFocalPoint = Offset.zero;
  bool _isInteractingWithRuler = false;

  @override
  void initState() {
    super.initState();
    _visualPosition = widget.position;
    
    _ticker = createTicker((elapsed) {
       _onTick();
    });
  }
  
  void _onTick() {
     // Poll the provider directly for the atomic position!
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
    super.dispose();
  }
  
  double get _msPerBeat {
    if (widget.bpm != null && widget.bpm! > 0) {
      return 60000.0 / widget.bpm!;
    }
    return 0; // Means no snapping
  }

  double _snapToGrid(double ms, double totalMs, double viewWidth) {
    final double beatMs = _msPerBeat;
    if (beatMs <= 0) return ms;

    final double msPerMeasure = beatMs * (widget.timeSignatureNumerator ?? 4);
    final double virtualWidth = viewWidth * _zoomLevel;
    final double pixelsPerMeasure = (msPerMeasure / totalMs) * virtualWidth;

    // Use measure snapping if zoomed out (e.g. less than 30 pixels per measure)
    if (pixelsPerMeasure < 30) {
        double snapped = (ms / msPerMeasure).round() * msPerMeasure;
        return snapped.clamp(0.0, totalMs);
    } else {
        // Normal beat snapping
        double snapped = (ms / beatMs).round() * beatMs;
        return snapped.clamp(0.0, totalMs);
    }
  }
  
  @override
  void didUpdateWidget(WaveformSeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    
    // If position changed from parent (e.g. seek while paused) and we aren't dragging,
    // update our visual position to match.
    if (widget.position != oldWidget.position && _dragPosition == null) {
        final mixer = context.read<MixerProvider>();
        if (!mixer.isPlaying) {
            _visualPosition = widget.position;
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    // ...
    // Verify Ticker State
    final mixer = context.watch<MixerProvider>(); // Listen to changes
    if (mixer.isPlaying && !_ticker.isActive) {
        _ticker.start();
    } else if (!mixer.isPlaying && _ticker.isActive) {
        _ticker.stop();
        // Snap to final
        _visualPosition = mixer.currentPosition;
    }
    
    final double totalMilliseconds = widget.duration.inMilliseconds.toDouble();
    // Use _visualPosition instead of widget.position!
    final double currentMilliseconds = _dragPosition?.inMilliseconds.toDouble() ?? _visualPosition.inMilliseconds.toDouble();
    
    // ...
    if (totalMilliseconds <= 0) return const SizedBox(height: 40);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = 100.0; // Taller fixed height for waveform

        return GestureDetector(
          onScaleStart: (details) => _handleScaleStart(details, width, totalMilliseconds),
          onScaleUpdate: (details) => _handleScaleUpdate(details, width, totalMilliseconds),
          onScaleEnd: (details) => _handleScaleEnd(details),
          onTapUp: (details) => _handleTap(details, width, totalMilliseconds),
          child: Column(
            children: [
              if (widget.bpm != null && widget.bpm! > 0 && widget.timeSignatureNumerator != null && widget.timeSignatureNumerator! > 0)
                _buildLoopRuler(width, totalMilliseconds),
              // Waveform Display (Clipped to prevent drawing over transport)
              ClipRect(
                child: Container(
                  height: height,
                  width: width,
                  color: Colors.black26, // Background
                  child: CustomPaint(
                    painter: WaveformPainter(
                      waveformData: widget.waveformData,
                      position: Duration(milliseconds: currentMilliseconds.toInt()),
                      duration: widget.duration,
                      color: Colors.cyanAccent,
                      isLoopEnabled: widget.isLoopEnabled,
                      loopStart: _dragLoopStart ?? widget.loopStart,
                      loopEnd: _dragLoopEnd ?? widget.loopEnd,
                      zoomLevel: _zoomLevel,
                      scrollOffset: _scrollOffset,
                    ),
                  ),
                ),
              ),
              
              // Time Labels only
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
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
      );
    },
  );
  }

  // --- LOOP RULER ---
  Widget _buildLoopRuler(double width, double totalMs) {
     return Container(
        height: 24, // Taller for better touch target
        width: width,
        decoration: const BoxDecoration(
          color: Color(0xFF1E1E1E),
          border: Border(bottom: BorderSide(color: Colors.white24, width: 1)),
        ),
        child: CustomPaint(
           painter: LoopRulerPainter(
              bpm: widget.bpm!,
              timeSignatureTop: widget.timeSignatureNumerator!,
              preWaitMeasures: widget.preWaitMeasures,
              countInMeasures: widget.countInMeasures,
              duration: widget.duration,
              loopStart: _dragLoopStart ?? widget.loopStart,
              loopEnd: _dragLoopEnd ?? widget.loopEnd,
              isLoopEnabled: widget.isLoopEnabled,
              zoomLevel: _zoomLevel,
              scrollOffset: _scrollOffset,
           ),
        ),
     );
  }

  // --- TRANSFORMS ---
  double _getMsFromLocalX(double localX, double viewWidth, double totalMs) {
      double virtualWidth = viewWidth * _zoomLevel;
      double absoluteX = localX + _scrollOffset;
      if (absoluteX < 0) absoluteX = 0;
      if (absoluteX > virtualWidth) absoluteX = virtualWidth;
      
      double ms = (absoluteX / virtualWidth) * totalMs;
      // When tracking seek or drag, we don't necessarily snap immediately? Wait, snapping happens in _snapToGrid.
      return ms;
  }

  // --- SCALE GESTURES (Zoom & Pan & Single Drag) ---
  void _handleScaleStart(ScaleStartDetails details, double width, double totalMs) {
      if (details.pointerCount == 1) {
          // Identify if it's Ruler or Waveform
          _isInteractingWithRuler = (details.localFocalPoint.dy <= 24.0) && widget.isLoopEnabled;
          if (_isInteractingWithRuler) {
             _handleLoopDragStart(details.localFocalPoint, width, totalMs);
          } else {
             // Start seek drag
             double ms = _getMsFromLocalX(details.localFocalPoint.dx, width, totalMs);
             _dragPosition = Duration(milliseconds: ms.toInt().clamp(0, totalMs.toInt()));
             setState(() {});
          }
      } else if (details.pointerCount >= 2) {
          _baseZoomLevel = _zoomLevel;
          _initialScrollOffset = _scrollOffset;
          _initialFocalPoint = details.localFocalPoint;
      }
  }
  void _handleScaleUpdate(ScaleUpdateDetails details, double width, double totalMs) {
      if (details.pointerCount == 1) {
          if (_isInteractingWithRuler) {
             _handleLoopDragUpdate(details.localFocalPoint, width, totalMs);
          } else {
             // Update seek drag
             double ms = _getMsFromLocalX(details.localFocalPoint.dx, width, totalMs);
             _dragPosition = Duration(milliseconds: ms.toInt().clamp(0, totalMs.toInt()));
             setState(() {});
          }
      } else if (details.pointerCount >= 2) {
          // Zoom and Pan
          double newZoom = (_baseZoomLevel * details.scale).clamp(1.0, 50.0);
          
          double virtualXStart = _initialFocalPoint.dx + _initialScrollOffset;
          double virtualXNew = virtualXStart * (newZoom / _baseZoomLevel);
          // Account for pan distance simply by using details.localFocalPoint.dx
          double newScrollOffset = virtualXNew - details.localFocalPoint.dx;
          
          double maxScroll = (width * newZoom) - width;
          
          setState(() {
              _zoomLevel = newZoom;
              _scrollOffset = newScrollOffset.clamp(0.0, maxScroll >= 0 ? maxScroll : 0.0);
          });
      }
  }

  void _handleScaleEnd(ScaleEndDetails details) {
      if (_isInteractingWithRuler) {
          _handleLoopDragEnd();
      } else if (_dragPosition != null) {
          // End Seek Drag
          if (widget.onSeek != null) {
             widget.onSeek!(_dragPosition!);
          }
          _visualPosition = _dragPosition!;
          _dragPosition = null;
          setState(() {});
      }
      _isInteractingWithRuler = false;
  }

  // --- LOOP HANDLE DRAG (Ruler) ---
  void _handleLoopDragStart(Offset localPosition, double width, double totalMs) {
    if (!widget.isLoopEnabled) return;

    double touchMs = _getMsFromLocalX(localPosition.dx, width, totalMs);
    
    // Hit test tolerance (converted to Ms based on zoom level for consistent physical touch size)
    final double toleranceMs = (40.0 / (width * _zoomLevel)) * totalMs; 
    
    final double loopStartMs = widget.loopStart.inMilliseconds.toDouble();
    final double loopEndMs = widget.loopEnd.inMilliseconds.toDouble();

    // Check handles
    double distStart = (touchMs - loopStartMs).abs();
    double distEnd = (touchMs - loopEndMs).abs();
    
    bool hitStart = distStart < toleranceMs;
    bool hitEnd = distEnd < toleranceMs;
    
    // Reset seek drag if it started accidentally
    _dragPosition = null; 

    if (hitStart && hitEnd) {
       if (distEnd <= distStart) {
           _isDraggingLoopEnd = true;
           _dragLoopEnd = widget.loopEnd;
       } else {
           _isDraggingLoopStart = true;
           _dragLoopStart = widget.loopStart;
       }
    } else if (hitStart) {
       _isDraggingLoopStart = true;
       _dragLoopStart = widget.loopStart;
    } else if (hitEnd) {
       _isDraggingLoopEnd = true;
       _dragLoopEnd = widget.loopEnd;
    } else {
       // Optional: Tap in middle creates new loop? Let's keep it simple and just snap to nearest handle if they miss, or do nothing.
       // Actually, maybe tap creates new loop around that beat?
       // For now, let's just do nothing if they miss cleanly, or snap the nearest handle if they were close.
       if (distStart < distEnd) {
           _isDraggingLoopStart = true;
           _dragLoopStart = widget.loopStart;
       } else {
           _isDraggingLoopEnd = true;
           _dragLoopEnd = widget.loopEnd;
       }
    }
    
    if (_isDraggingLoopStart || _isDraggingLoopEnd) {
       // Feedback
       HapticFeedback.selectionClick();
       setState(() {});
    }
  }

  void _handleLoopDragUpdate(Offset localPosition, double width, double totalMs) {
      // Calculate absolute position
     double newMs = _getMsFromLocalX(localPosition.dx, width, totalMs);
     newMs = _snapToGrid(newMs, totalMs, width);
     
     if (_isDraggingLoopStart) {
        final val = Duration(milliseconds: newMs.toInt());
        if (val < widget.loopEnd) {
           _dragLoopStart = val;
           if (widget.onLoopRangeChanged != null) {
              widget.onLoopRangeChanged!(_dragLoopStart!, widget.loopEnd);
           }
        }
     } else if (_isDraggingLoopEnd) {
         final val = Duration(milliseconds: newMs.toInt());
         if (val > widget.loopStart) {
            _dragLoopEnd = val;
            if (widget.onLoopRangeChanged != null) {
               widget.onLoopRangeChanged!(widget.loopStart, _dragLoopEnd!);
            }
         }
     }
     setState(() {});
  }

  void _handleLoopDragEnd() {
      if (_isDraggingLoopStart || _isDraggingLoopEnd) {
         if (widget.onLoopRangeChangeEnd != null) {
            widget.onLoopRangeChangeEnd!(_dragLoopStart ?? widget.loopStart, _dragLoopEnd ?? widget.loopEnd);
         }
         
         _isDraggingLoopStart = false;
         _isDraggingLoopEnd = false;
         _dragLoopStart = null;
         _dragLoopEnd = null;
         setState(() {});
      }
  }
  
  void _handleTap(TapUpDetails details, double width, double totalMs) {
     // Identify if we tapped the loop ruler, if so, ignore seek
     if (details.localPosition.dy <= 24.0 && widget.isLoopEnabled) return;

     // Simple seek on tap
     double newMs = _getMsFromLocalX(details.localPosition.dx, width, totalMs);
     if (widget.onSeek != null) {
        final newDur = Duration(milliseconds: newMs.toInt());
        widget.onSeek!(newDur);
        _visualPosition = newDur;
        setState(() {});
     }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}


import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/widgets/waveform/waveform_painter.dart';

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
        final height = 60.0; // Fixed height for waveform

        return Column(
          children: [
            // Waveform & Interaction Area
            GestureDetector(
              // Tap to Seek
              onTapUp: (details) => _handleTap(details, width, totalMilliseconds),
              
              // Standard Drag -> Seek
              onHorizontalDragStart: (details) => _handleSeekDragStart(details, width, totalMilliseconds),
              onHorizontalDragUpdate: (details) => _handleSeekDragUpdate(details, width, totalMilliseconds),
              onHorizontalDragEnd: (details) => _handleSeekDragEnd(details),

              // Long Press -> Loop Handle Drag
              onLongPressStart: (details) => _handleLongPressStart(details, width, totalMilliseconds),
              onLongPressMoveUpdate: (details) => _handleLongPressUpdate(details, width, totalMilliseconds),
              onLongPressEnd: (details) => _handleLongPressEnd(details),
              
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
                  ),
                ),
              ),
            ),
            
            // Time Labels & Loop Toggle
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _formatDuration(Duration(milliseconds: currentMilliseconds.toInt())),
                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: "monospace"),
                  ),
                   
                  // Loop Toggle Button
                  InkWell(
                     onTap: () {
                        if (widget.onLoopToggle != null) {
                           widget.onLoopToggle!(!widget.isLoopEnabled);
                        }
                     },
                     borderRadius: BorderRadius.circular(16),
                     child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                           color: widget.isLoopEnabled ? Colors.cyanAccent.withValues(alpha: 0.2) : Colors.transparent,
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(color: widget.isLoopEnabled ? Colors.cyanAccent : Colors.white24),
                        ),
                        child: Row(
                           children: [
                               Icon(Icons.loop, size: 14, color: widget.isLoopEnabled ? Colors.cyanAccent : Colors.white54),
                               const SizedBox(width: 4),
                               Text(widget.isLoopEnabled ? "LOOP ON" : "LOOP", 
                                  style: TextStyle(
                                     fontSize: 10, 
                                     color: widget.isLoopEnabled ? Colors.cyanAccent : Colors.white54,
                                     fontWeight: FontWeight.bold
                                  )
                               ),
                           ],
                        ),
                     ),
                  ),

                  Text(
                    _formatDuration(widget.duration),
                    style: const TextStyle(fontSize: 12, color: Colors.white70, fontFamily: "monospace"),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  // --- SEEK DRAG ---
  void _handleSeekDragStart(DragStartDetails details, double width, double totalMs) {
      // If we are already handling a long press, ignore standard drag?
      // Actually standard drag might fire first. 
      // But we want "Hold to manage bar".
      // Let's allow immediate seek on drag.
      
      final double touchPercent = details.localPosition.dx / width;
      final double touchMs = touchPercent * totalMs;
      _dragPosition = Duration(milliseconds: touchMs.toInt());
      setState(() {});
  }

  void _handleSeekDragUpdate(DragUpdateDetails details, double width, double totalMs) {
     if (_isDraggingLoopStart || _isDraggingLoopEnd) return; // Don't seek if loop dragging active (safety)

     final double deltaPercent = details.primaryDelta! / width;
     final double totalMsDelta = deltaPercent * totalMs;
     final currentMs = (_dragPosition?.inMilliseconds.toDouble() ?? widget.position.inMilliseconds.toDouble());
     final newMs = (currentMs + totalMsDelta).clamp(0.0, totalMs);
     _dragPosition = Duration(milliseconds: newMs.toInt());
     setState(() {});
  }

  void _handleSeekDragEnd(DragEndDetails details) {
     if (_isDraggingLoopStart || _isDraggingLoopEnd) return;

     if (_dragPosition != null) {
        if (widget.onSeek != null) {
           widget.onSeek!(_dragPosition!);
        }
        // Snap the visual position so when drag state clears, it doesn't jump back
        _visualPosition = _dragPosition!;
     }
     _dragPosition = null;
     setState(() {});
  }

  // --- LOOP HANDLE LONG PRESS ---
  void _handleLongPressStart(LongPressStartDetails details, double width, double totalMs) {
    if (!widget.isLoopEnabled) return;

    final double touchPercent = details.localPosition.dx / width;
    
    // Hit test tolerance (Increased for accessibility)
    final double tolerancePercent = 40.0 / width; 
    
    final double loopStartPercent = widget.loopStart.inMilliseconds / totalMs;
    final double loopEndPercent = widget.loopEnd.inMilliseconds / totalMs;

    // Check handles
    double distStart = (touchPercent - loopStartPercent).abs();
    double distEnd = (touchPercent - loopEndPercent).abs();
    
    bool hitStart = distStart < tolerancePercent;
    bool hitEnd = distEnd < tolerancePercent;
    
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
    }
    
    if (_isDraggingLoopStart || _isDraggingLoopEnd) {
       // Feedback
       HapticFeedback.selectionClick();
       setState(() {});
    }
  }

  void _handleLongPressUpdate(LongPressMoveUpdateDetails details, double width, double totalMs) {
      // Delta is tricky with LongPressMoveUpdateDetails, uses localPosition relative to start?
      // It gives `localPosition`. We can calculate absolute position.
      
     final double touchPercent = details.localPosition.dx / width;
     final double newMs = (touchPercent * totalMs).clamp(0.0, totalMs);
     
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

  void _handleLongPressEnd(LongPressEndDetails details) {
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
     // Simple seek on tap
     final double touchPercent = details.localPosition.dx / width;
     final int newMs = (touchPercent * totalMs).toInt();
     if (widget.onSeek != null) {
        final newDur = Duration(milliseconds: newMs);
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

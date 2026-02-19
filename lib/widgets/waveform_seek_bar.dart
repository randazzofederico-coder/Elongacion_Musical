
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
    
    // Check if we should be ticking
    // We can't easily check isPlaying from widget props accurately if it comes from stream?
    // Actually we don't have isPlaying prop here.
    // But we have context.read in _onTick.
    // The issue is starting/stopping the ticker.
    
    // Let's check context.read<MixerProvider>().isPlaying ? 
    // But didUpdateWidget doesn't rebuild on provider change unless we listen.
    // The parent (TransportSection) DOES listen/rebuild. 
    // IF we pass isPlaying to WaveformSeekBar, we can control ticker efficiently.
    // The user reverted `isPlaying` prop in my previous revert.
    
    // For now, let's just always run ticker if mounted? 
    // Or add `isPlaying` back to WaveformSeekBar?
    
    // The user said "Lets go back to previos state".
    // I reverted to state WITHOUT isPlaying.
    // But to get 60fps smoothing, I really should control the Ticker.
    
    // If I don't adds `isPlaying`, I can just rely on the parent rebuilding us?
    // No, `WaveformSeekBar` is a StatefulWidget.
    
    // Let's modify `TransportSection` to pass `isPlaying` again? 
    // It's cleaner.
    // But failing that, we can listen to the stream?
    
    // Actually, `WaveformSeekBar` takes `position`.
    // If the stream is updating (even slowly), we are getting updates.
    // We want to ignore the slow stream updates for rendering and use the fast ticker updates.
    
    // Wait, if I use Ticker, I don't need `widget.position` for the playhead (except initial sync).
    // I will use `_visualPosition` which I poll from `MixerProvider` (via context is a bit dirty inside a widget, but ok).
    
    // Crucially: When is the Ticker active?
    // I'll add `isPlaying` to `WaveformSeekBar` construction in `TransportSection`.
    // It's a tiny change that enables the "Engine" of the UI.
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

     if (_dragPosition != null && widget.onSeek != null) {
        widget.onSeek!(_dragPosition!);
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
        widget.onSeek!(Duration(milliseconds: newMs));
     }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }
}

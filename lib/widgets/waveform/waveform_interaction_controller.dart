import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/gestures.dart';

class WaveformInteractionController extends ChangeNotifier {
  Duration duration;
  int? bpm;
  int? timeSignatureNumerator;
  bool isLoopEnabled;
  Duration initialLoopStart;
  Duration initialLoopEnd;
  
  ValueChanged<Duration>? onSeek;
  Function(Duration start, Duration end)? onLoopRangeChanged;
  Function(Duration start, Duration end)? onLoopRangeChangeEnd;

  // Visual State
  Duration? dragPosition;
  double zoomLevel = 1.0;
  double scrollOffset = 0.0;

  // Loop Drag State
  bool isDraggingLoopStart = false;
  bool isDraggingLoopEnd = false;
  Duration? dragLoopStart;
  Duration? dragLoopEnd;

  // Internal Gesture Tracking
  double _baseZoomLevel = 1.0;
  double _initialScrollOffset = 0.0;
  Offset _initialFocalPoint = Offset.zero;
  bool _isInteractingWithRuler = false;
  int _activePointers = 0;
  bool _sessionWasZooming = false;
  int _activeMouseButton = 0;

  WaveformInteractionController({
    required this.duration,
    this.bpm,
    this.timeSignatureNumerator,
    this.isLoopEnabled = false,
    this.initialLoopStart = Duration.zero,
    this.initialLoopEnd = Duration.zero,
    this.onSeek,
    this.onLoopRangeChanged,
    this.onLoopRangeChangeEnd,
  });

  double get totalMs => duration.inMilliseconds.toDouble();

  // --- Grid Snapping Math ---
  double get _msPerBeat {
    if (bpm != null && bpm! > 0) {
      return 60000.0 / bpm!;
    }
    return 0; // Means no snapping
  }

  double _snapToGrid(double ms, double viewWidth) {
    if (totalMs <= 0) return 0;
    
    final double beatMs = _msPerBeat;
    if (beatMs <= 0) return ms;

    final double msPerMeasure = beatMs * (timeSignatureNumerator ?? 4);
    final double virtualWidth = viewWidth * zoomLevel;
    final double pixelsPerMeasure = (msPerMeasure / totalMs) * virtualWidth;

    if (pixelsPerMeasure < 30) {
        double snapped = (ms / msPerMeasure).round() * msPerMeasure;
        return snapped.clamp(0.0, totalMs);
    } else {
        double snapped = (ms / beatMs).round() * beatMs;
        return snapped.clamp(0.0, totalMs);
    }
  }

  double _getMsFromLocalX(double localX, double viewWidth) {
      if (totalMs <= 0) return 0;
      double virtualWidth = viewWidth * zoomLevel;
      double absoluteX = localX + scrollOffset;
      if (absoluteX < 0) absoluteX = 0;
      if (absoluteX > virtualWidth) absoluteX = virtualWidth;
      
      return (absoluteX / virtualWidth) * totalMs;
  }

  // --- Pointer Handlers ---
  void handlePointerDown(PointerDownEvent event) {
     _activePointers++;
     if (_activePointers == 1) {
         _activeMouseButton = event.buttons;
     }

     if (_activePointers >= 2) {
         _sessionWasZooming = true;
         if (dragPosition != null || isDraggingLoopStart || isDraggingLoopEnd) {
             dragPosition = null;
             isDraggingLoopStart = false;
             isDraggingLoopEnd = false;
             dragLoopStart = null;
             dragLoopEnd = null;
             notifyListeners();
         }
     }
  }

  void handlePointerMove(PointerMoveEvent event, double width) {
     if (_activeMouseButton == kSecondaryMouseButton || _activeMouseButton == kMiddleMouseButton) {
        double maxScroll = (width * zoomLevel) - width;
        scrollOffset -= event.delta.dx;
        scrollOffset = scrollOffset.clamp(0.0, maxScroll >= 0 ? maxScroll : 0.0);
        notifyListeners();
     }
  }

  void handlePointerSignal(PointerSignalEvent event, double width) {
     if (event is PointerScrollEvent) {
        final keyboard = HardwareKeyboard.instance;
        bool isZoomModifiers = keyboard.isControlPressed || keyboard.isAltPressed || keyboard.isShiftPressed;
                               
        if (isZoomModifiers) {
           double zoomDelta = -event.scrollDelta.dy * 0.005; 
           double newZoom = (zoomLevel + zoomDelta).clamp(1.0, 50.0);
           
           double pointerMs = _getMsFromLocalX(event.localPosition.dx, width);
           
           zoomLevel = newZoom;
           if (totalMs > 0) {
               double newScrollOffset = (pointerMs / totalMs) * (width * newZoom) - event.localPosition.dx;
               double maxScroll = (width * newZoom) - width;
               scrollOffset = newScrollOffset.clamp(0.0, maxScroll >= 0 ? maxScroll : 0.0);
           }
           notifyListeners();
        } else {
           double maxScroll = (width * zoomLevel) - width;
           double panDelta = event.scrollDelta.dx != 0 ? event.scrollDelta.dx : event.scrollDelta.dy;
           if (keyboard.isShiftPressed) {
               panDelta = event.scrollDelta.dy != 0 ? event.scrollDelta.dy : panDelta;
           }
           
           scrollOffset += panDelta;
           scrollOffset = scrollOffset.clamp(0.0, maxScroll >= 0 ? maxScroll : 0.0);
           notifyListeners();
        }
     }
  }

  void handlePointerUp(PointerUpEvent event) {
     _activePointers--;
     if (_activePointers <= 0) {
         _activePointers = 0;
         _activeMouseButton = 0;
         Future.microtask(() {
             if (_activePointers == 0) {
                 _sessionWasZooming = false;
             }
         });
     }
  }

  void handlePointerCancel(PointerCancelEvent event) {
     _activePointers--;
     if (_activePointers <= 0) {
         _activePointers = 0;
         _activeMouseButton = 0;
         Future.microtask(() {
             if (_activePointers == 0) {
                 _sessionWasZooming = false;
             }
         });
     }
  }

  void setScrollOffsetFromRatio(double ratio, double width) {
     if (totalMs <= 0) return;
     double virtualWidth = width * zoomLevel;
     double maxScroll = virtualWidth - width;
     
     if (maxScroll <= 0) return;
     
     scrollOffset = (ratio * virtualWidth).clamp(0.0, maxScroll);
     notifyListeners();
  }

  // --- Scale / Zoom / Pan Handlers ---
  void handleScaleStart(ScaleStartDetails details, double width) {
      if (_sessionWasZooming) {
          if (details.pointerCount >= 2) {
              _baseZoomLevel = zoomLevel;
              _initialScrollOffset = scrollOffset;
              _initialFocalPoint = details.localFocalPoint;
          }
          return;
      }
      
      if (details.pointerCount == 1) {
          _isInteractingWithRuler = (details.localFocalPoint.dy <= 24.0) && isLoopEnabled;
          if (_isInteractingWithRuler) {
             _handleLoopDragStart(details.localFocalPoint, width);
          } else {
             double ms = _getMsFromLocalX(details.localFocalPoint.dx, width);
             dragPosition = Duration(milliseconds: ms.toInt().clamp(0, totalMs.toInt()));
             notifyListeners();
          }
      }
  }

  void handleScaleUpdate(ScaleUpdateDetails details, double width) {
      if (_sessionWasZooming) {
          if (details.pointerCount >= 2) {
              double newZoom = (_baseZoomLevel * details.scale).clamp(1.0, 50.0);
              
              double virtualXStart = _initialFocalPoint.dx + _initialScrollOffset;
              double virtualXNew = virtualXStart * (newZoom / _baseZoomLevel);
              double newScrollOffset = virtualXNew - details.localFocalPoint.dx;
              
              double maxScroll = (width * newZoom) - width;
              
              zoomLevel = newZoom;
              scrollOffset = newScrollOffset.clamp(0.0, maxScroll >= 0 ? maxScroll : 0.0);
              notifyListeners();
          }
          return;
      }

      if (details.pointerCount == 1) {
          if (_isInteractingWithRuler) {
             _handleLoopDragUpdate(details.localFocalPoint, width);
          } else {
             double ms = _getMsFromLocalX(details.localFocalPoint.dx, width);
             dragPosition = Duration(milliseconds: ms.toInt().clamp(0, totalMs.toInt()));
             notifyListeners();
          }
      }
  }

  void handleScaleEnd(ScaleEndDetails details) {
      if (_sessionWasZooming) return;

      if (_isInteractingWithRuler) {
          _handleLoopDragEnd();
      } else if (dragPosition != null) {
          if (onSeek != null) {
             onSeek!(dragPosition!);
          }
          dragPosition = null;
          notifyListeners();
      }
      _isInteractingWithRuler = false;
  }

  // --- Tap Handler ---
  void handleTap(TapUpDetails details, double width) {
     if (_sessionWasZooming) return;
     if (details.localPosition.dy <= 24.0 && isLoopEnabled) return;

     double newMs = _getMsFromLocalX(details.localPosition.dx, width);
     if (onSeek != null) {
        final newDur = Duration(milliseconds: newMs.toInt());
        onSeek!(newDur);
     }
  }

  // --- Loop Drag Handlers ---
  void _handleLoopDragStart(Offset localPosition, double width) {
    if (!isLoopEnabled) return;

    double touchMs = _getMsFromLocalX(localPosition.dx, width);
    final double toleranceMs = (40.0 / (width * zoomLevel)) * totalMs; 
    
    final currentLoopStart = dragLoopStart ?? initialLoopStart;
    final currentLoopEnd = dragLoopEnd ?? initialLoopEnd;
    
    final double loopStartMs = currentLoopStart.inMilliseconds.toDouble();
    final double loopEndMs = currentLoopEnd.inMilliseconds.toDouble();

    double distStart = (touchMs - loopStartMs).abs();
    double distEnd = (touchMs - loopEndMs).abs();
    
    bool hitStart = distStart < toleranceMs;
    bool hitEnd = distEnd < toleranceMs;
    
    dragPosition = null; 

    if (hitStart && hitEnd) {
       if (distEnd <= distStart) {
           isDraggingLoopEnd = true;
           dragLoopEnd = currentLoopEnd;
       } else {
           isDraggingLoopStart = true;
           dragLoopStart = currentLoopStart;
       }
    } else if (hitStart) {
       isDraggingLoopStart = true;
       dragLoopStart = currentLoopStart;
    } else if (hitEnd) {
       isDraggingLoopEnd = true;
       dragLoopEnd = currentLoopEnd;
    } else {
       if (distStart < distEnd) {
           isDraggingLoopStart = true;
           dragLoopStart = currentLoopStart;
       } else {
           isDraggingLoopEnd = true;
           dragLoopEnd = currentLoopEnd;
       }
    }
    
    if (isDraggingLoopStart || isDraggingLoopEnd) {
       HapticFeedback.selectionClick();
       notifyListeners();
    }
  }

  void _handleLoopDragUpdate(Offset localPosition, double width) {
     double newMs = _getMsFromLocalX(localPosition.dx, width);
     newMs = _snapToGrid(newMs, width);
     
     final currentLoopStart = dragLoopStart ?? initialLoopStart;
     final currentLoopEnd = dragLoopEnd ?? initialLoopEnd;

     if (isDraggingLoopStart) {
        final val = Duration(milliseconds: newMs.toInt());
        if (val < currentLoopEnd) {
           dragLoopStart = val;
           if (onLoopRangeChanged != null) {
              onLoopRangeChanged!(dragLoopStart!, currentLoopEnd);
           }
        }
     } else if (isDraggingLoopEnd) {
         final val = Duration(milliseconds: newMs.toInt());
         if (val > currentLoopStart) {
            dragLoopEnd = val;
            if (onLoopRangeChanged != null) {
               onLoopRangeChanged!(currentLoopStart, dragLoopEnd!);
            }
         }
     }
     notifyListeners();
  }

  void _handleLoopDragEnd() {
      if (isDraggingLoopStart || isDraggingLoopEnd) {
         if (onLoopRangeChangeEnd != null) {
            onLoopRangeChangeEnd!(
                dragLoopStart ?? initialLoopStart, 
                dragLoopEnd ?? initialLoopEnd
            );
         }
         
         isDraggingLoopStart = false;
         isDraggingLoopEnd = false;
         // dragLoopStart/End deliberately kept so UI reflects new value
         // until Widget rebuilds and re-creates controller.
         notifyListeners();
      }
  }
}

import 'dart:math';
import 'package:flutter/material.dart';

class FaderControl extends StatefulWidget {
  final double volume; // Linear Amplitude (0.0 to 2.0+)
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final Color color;

  const FaderControl({
    super.key,
    required this.volume,
    required this.onChanged,
    required this.onChangeEnd,
    this.color = Colors.cyanAccent,
  });

  @override
  State<FaderControl> createState() => _FaderControlState();
}

class _FaderControlState extends State<FaderControl> {
  // Mapping Constants
  // We map normalized UI position (0.0 bottom to 1.0 top) to Amplitude.
  // Goal: 0.75 position = 0dB (Amplitude 1.0)
  //       1.00 position = +6dB (Amplitude ~2.0)
  
  // Using a piecewise approximation for a good feel:
  // Segment 1 (0.0 to 0.75): Exponential rise from 0 to 1.0
  // Segment 2 (0.75 to 1.0): Linear rise from 1.0 to 2.0 (approx +6dB)
  
  double _amplitudeToPosition(double amp) {
    if (amp <= 1.0) {
      // Inverse of pos^2 * k? 
      // Let's use simple: pos = 0.75 * sqrt(amp)
      // Check: amp=1 -> pos=0.75. amp=0 -> pos=0. 
      // amp=0.25 (-12dB) -> pos=0.375.
      return 0.75 * sqrt(max(0, amp));
    } else {
      // Linear interpolation from 1.0 -> 2.0 mapped to 0.75 -> 1.0
      // slope = (1.0 - 0.75) / (2.0 - 1.0) = 0.25
      return 0.75 + (amp - 1.0) * 0.25;
    }
  }

  double _positionToAmplitude(double pos) {
    if (pos <= 0.75) {
      // amp = (pos / 0.75)^2
      final norm = pos / 0.75;
      return norm * norm;
    } else {
      // amp = 1.0 + (pos - 0.75) / 0.25
      return 1.0 + (pos - 0.75) * 4.0;
    }
  }

  String _amplitudeToDbString(double amp) {
    if (amp <= 0.0001) return "-Inf";
    final db = 20 * log(amp) / ln10;
    return "${db > 0 ? '+' : ''}${db.toStringAsFixed(1)}";
  }

  void _handleDrag(double dy, double height) {
    // dy is from top, so we invert
    double localY = (height - dy).clamp(0.0, height);
    double pos = localY / height;
    
    double newAmp = _positionToAmplitude(pos);
    widget.onChanged(newAmp);
  }

  void _showValueDialog(BuildContext context) {
    final controller = TextEditingController(text: _amplitudeToDbString(widget.volume).replaceAll(" dB", ""));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Colors.grey.shade900,
        title: const Text("Enter Volume (dB)", style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(
            hintText: "e.g. -6.0",
            hintStyle: TextStyle(color: Colors.grey),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              final val = double.tryParse(controller.text);
              if (val != null) {
                // Convert dB to Amp
                // V = 10 ^ (dB/20)
                final amp = pow(10, val / 20).toDouble();
                widget.onChanged(amp);
                widget.onChangeEnd(amp);
              }
              Navigator.pop(ctx);
            },
            child: const Text("OK"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double position = _amplitudeToPosition(widget.volume);
    final String dbLabel = _amplitudeToDbString(widget.volume);

    return Column(
      children: [
        // Value Text (Tap to edit)
        GestureDetector(
          onTap: () => _showValueDialog(context),
          child: Container(
            height: 20,
            alignment: Alignment.center,
            child: Text(
              dbLabel,
              style: TextStyle(
                color: widget.color, 
                fontSize: 10, 
                fontWeight: FontWeight.bold
              ),
            ),
          ),
        ),
        
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;
              
              // Thumb Y position (0 at top visually for canvas?)
              // Canvas usually (0,0) top-left.
              // So thumb Y = h - (position * h)
              
              return GestureDetector(
                onVerticalDragUpdate: (details) {
                  _handleDrag(details.localPosition.dy, h);
                },
                onVerticalDragEnd: (_) {
                  widget.onChangeEnd(widget.volume);
                },
                onTapDown: (details) {
                   _handleDrag(details.localPosition.dy, h);
                   widget.onChangeEnd(widget.volume); // Immediate commit on tap
                },
                onDoubleTap: () {
                  // Reset to 0dB (Amplitude 1.0)
                  widget.onChanged(1.0);
                  widget.onChangeEnd(1.0);
                },
                child: CustomPaint(
                  size: Size(w, h),
                  painter: _FaderPainter(
                    position: position,
                    unityPos: 0.75,
                    color: widget.color,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _FaderPainter extends CustomPainter {
  final double position; // 0.0 to 1.0
  final double unityPos;
  final Color color;

  _FaderPainter({required this.position, required this.unityPos, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    final centerX = w / 2;
    
    // 1. Groove (Background Track)
    final paintGroove = Paint()
      ..color = Colors.black45
      ..strokeWidth = 4
      ..strokeCap = StrokeCap.round;
      
    canvas.drawLine(
      Offset(centerX, 0),
      Offset(centerX, h),
      paintGroove,
    );
    
    // 2. Active Line (Colored, Thin)
    // From Bottom (h) to Current Pos
    final thumbY = h - (position * h);
    
    final paintActive = Paint()
      ..color = color //.withOpacity(0.8)
      ..strokeWidth = 2; // "muccho mas fina"
      
    canvas.drawLine(
      Offset(centerX, thumbY),
      Offset(centerX, h),
      paintActive,
    );
    
    // 3. Unity Marker (0dB)
    final unityY = h - (unityPos * h);
    final paintMarker = Paint()
      ..color = Colors.white30
      ..strokeWidth = 1;
      
    canvas.drawLine(
      Offset(centerX - 6, unityY),
      Offset(centerX + 6, unityY),
      paintMarker,
    );
    
    // 4. Thumb (Cap)
    // "Perilla tipica del slider" -> Rectangle/RoundedRect
    
    final thumbRect = Rect.fromCenter(
      center: Offset(centerX, thumbY),
      width: 24,
      height: 36, // Tall fader cap
    );
    
    final paintThumb = Paint()
      ..shader = const LinearGradient(
        colors: [Color(0xFF444444), Color(0xFF111111)],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(thumbRect);

    // Shadow
    final shadowPath = Path()..addRRect(RRect.fromRectAndRadius(thumbRect.translate(0, 2), const Radius.circular(3)));
    canvas.drawShadow(shadowPath, Colors.black, 3, true);

    // Body
    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect, const Radius.circular(3)),
      paintThumb,
    );
    
    // Center line on thumb
    final paintThumbLine = Paint()
      ..color = Colors.white
      ..strokeWidth = 2;
      
    canvas.drawLine(
      Offset(thumbRect.left + 2, thumbRect.center.dy),
      Offset(thumbRect.right - 2, thumbRect.center.dy),
      paintThumbLine,
    );
  }

  @override
  bool shouldRepaint(covariant _FaderPainter oldDelegate) {
    return oldDelegate.position != position;
  }
}

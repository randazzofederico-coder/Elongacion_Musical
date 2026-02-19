import 'dart:math';
import 'package:flutter/material.dart';

class KnobControl extends StatefulWidget {
  final double value;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd; // Added
  final double min;
  final double max;
  final String label;

  const KnobControl({
    super.key,
    required this.value,
    required this.onChanged,
    this.onChangeEnd,
    this.min = -1.0,
    this.max = 1.0,
    this.label = "PAN",
  });

  @override
  State<KnobControl> createState() => _KnobControlState();
}

class _KnobControlState extends State<KnobControl> {
  static const double _maxAngle = 2.35; // ~135 degrees in radians

  void _handlePanUpdate(DragUpdateDetails details) {
    double sensitivity = 0.005 * (widget.max - widget.min); // Scale sensitivity by range
    if (sensitivity == 0) sensitivity = 0.01;
    
    double delta = -details.delta.dy * sensitivity;
    double newValue = (widget.value + delta).clamp(widget.min, widget.max);
    
    if (newValue != widget.value) {
       widget.onChanged(newValue);
    }
  }

  void _handlePanEnd(DragEndDetails details) {
    if (widget.onChangeEnd != null) {
      widget.onChangeEnd!(widget.value);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Normalize value to -1..1 range for angle calculation
    // angle = mapped * maxAngle
    double range = widget.max - widget.min;
    double normalized = 0.0;
    if (range > 0) {
      normalized = (widget.value - widget.min) / range; // 0..1
      normalized = (normalized * 2) - 1; // -1..1
    }

    double angle = normalized * _maxAngle;

    return GestureDetector(
      onVerticalDragUpdate: _handlePanUpdate,
      onVerticalDragEnd: _handlePanEnd,
      onDoubleTap: () {
        // Reset to default? 
        // For Pan (min -1, max 1) -> 0
        // For Vol (min 0, max 1) -> 0.7? or 1.0?
        // Let's assume Middle of range
        double mid = (widget.min + widget.max) / 2;
        // Exception for Volume where we might want 0.75 (0db)? 
        // For now, simple center or max/min logic is too complex to guess. 
        // Just defaulting to center is safer for Pan.
        widget.onChanged(mid);
        if (widget.onChangeEnd != null) widget.onChangeEnd!(mid);
      },
      onTap: () {
        // _showValueDialog(context); // Temporarily identifying if we need this, keeping it simple for now
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          CustomPaint(
            size: const Size(40, 40),
            painter: KnobPainter(angle: angle, color: Theme.of(context).primaryColor),
          ),
          const SizedBox(height: 4),
          Text(
            widget.label, 
            style: const TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: Colors.grey)
          ),
        ],
      ),
    );
  }
}

class KnobPainter extends CustomPainter {
  final double angle;
  final Color color;

  KnobPainter({required this.angle, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2;

    final paintBg = Paint()
      ..color = Colors.grey.shade800
      ..style = PaintingStyle.fill;
      
    final paintIndicator = Paint()
      ..color = Colors.white
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..style = PaintingStyle.stroke;

    final paintAccent = Paint()
      ..color = color.withValues(alpha: 0.3) // updated deprecated withOpacity
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    // Draw background circle
    canvas.drawCircle(center, radius, paintBg);
    
    // Draw Arc indicators?
    // Angle 0 (Up) is our center reference (normalized 0)
    // Canvas 0 radians is 3 o'clock (Right)
    // So Up is -pi/2
    
    double drawAngle = angle - pi / 2;

    
    final markerRadius = radius * 0.6;
    final markerStart = Offset(
      center.dx + cos(drawAngle) * (radius * 0.2), 
      center.dy + sin(drawAngle) * (radius * 0.2)
    );
     final markerEnd = Offset(
      center.dx + cos(drawAngle) * markerRadius, 
      center.dy + sin(drawAngle) * markerRadius
    );
    
    // Draw marker line
    canvas.drawLine(markerStart, markerEnd, paintIndicator);
    
    // Draw surrounding ring
    canvas.drawCircle(center, radius, paintAccent);
  }

  @override
  bool shouldRepaint(covariant KnobPainter oldDelegate) {
    return oldDelegate.angle != angle || oldDelegate.color != color;
  }
}

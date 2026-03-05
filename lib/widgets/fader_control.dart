import 'dart:math';
import 'package:flutter/material.dart';
import 'package:elongacion_musical/constants/app_colors.dart';

class FaderControl extends StatefulWidget {
  final double volume; // Linear Amplitude (0.0 to 2.0+)
  final ValueChanged<double> onChanged;
  final ValueChanged<double> onChangeEnd;
  final Color? color;

  const FaderControl({
    super.key,
    required this.volume,
    required this.onChanged,
    required this.onChangeEnd,
    this.color,
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
        backgroundColor: AppColors.surfaceHighlight(context), // Warmer dialog
        title: Text("Volume (dB)", style: TextStyle(color: AppColors.textPrimary(context))),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
          style: TextStyle(color: AppColors.textPrimary(context)),
          decoration: InputDecoration(
            hintText: "e.g. -6.0",
            hintStyle: TextStyle(color: AppColors.textSecondary(context)),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.border(context))),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: AppColors.accentCyan(context))),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: TextStyle(color: AppColors.textSecondary(context))),
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
            child: Text("OK", style: TextStyle(color: AppColors.accentCyan(context), fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double position = _amplitudeToPosition(widget.volume);
    final String dbLabel = _amplitudeToDbString(widget.volume);
    final effectiveColor = widget.color ?? AppColors.accentAmber(context);
    final isDark = AppColors.isDark(context); // Get theme mode

    return Column(
      children: [
        // Value Text (Tap to edit)
        GestureDetector(
          onTap: () => _showValueDialog(context),
          child: Container(
            height: 24,
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: AppColors.background(context).withOpacity(0.5),
              borderRadius: BorderRadius.circular(4),
              border: Border.all(color: AppColors.border(context), width: 0.5),
            ),
            child: Text(
              dbLabel,
              style: TextStyle(
                color: effectiveColor, 
                fontSize: 10, 
                fontWeight: FontWeight.w800,
                fontFamily: 'monospace', // Studio console feel
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final h = constraints.maxHeight;
              final w = constraints.maxWidth;
              
              // Thumb Y position
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
                    color: effectiveColor,
                    textSecondaryColor: AppColors.textSecondary(context),
                    textPrimaryColor: AppColors.textPrimary(context),
                    trackBgColor: AppColors.faderTrack(context),
                    slitColor: isDark ? Colors.black87 : const Color(0xFF2A1C16),
                    isDark: isDark, // Pass boolean
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
  final Color textSecondaryColor;
  final Color textPrimaryColor;
  final Color trackBgColor;
  final Color slitColor;
  final bool isDark;

  _FaderPainter({
     required this.position,
     required this.unityPos,
     required this.color,
     required this.textSecondaryColor,
     required this.textPrimaryColor,
     required this.trackBgColor,
     required this.slitColor,
     required this.isDark,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    
    final centerX = w / 2;
    
    // 1. Recessed Track Background (Darker, Inner Shadow look)
    final trackWidth = 12.0;
    final trackRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, h / 2), width: trackWidth, height: h),
      const Radius.circular(6)
    );
    
    // Draw outer track inset
    final paintTrackBg = Paint()
      ..color = trackBgColor
      ..style = PaintingStyle.fill;
    canvas.drawRRect(trackRect, paintTrackBg);
    
    // Draw dark inner slit
    final slitWidth = 4.0;
    final slitRect = RRect.fromRectAndRadius(
      Rect.fromCenter(center: Offset(centerX, h / 2), width: slitWidth, height: h - 4),
      const Radius.circular(2)
    );
    final paintSlit = Paint()
      ..color = slitColor 
      ..style = PaintingStyle.fill;
    canvas.drawRRect(slitRect, paintSlit);
    // 2. Ticks (Scale markers)
    final paintTick = Paint()
      ..color = textSecondaryColor.withOpacity(0.5)
      ..strokeWidth = 1;
      
    // Draw 0dB slightly thicker
    final unityY = h - (unityPos * h);
    final paintZeroDb = Paint()
      ..color = textPrimaryColor
      ..strokeWidth = 2;
    canvas.drawLine(Offset(centerX - 14, unityY), Offset(centerX - 8, unityY), paintZeroDb);
    canvas.drawLine(Offset(centerX + 8, unityY), Offset(centerX + 14, unityY), paintZeroDb);

    // Draw some subtle ticks
    for(int i=1; i<=4; i++) {
        double posY = h - ((unityPos * (i/4)) * h);
        canvas.drawLine(Offset(centerX - 10, posY), Offset(centerX - 8, posY), paintTick);
    }
    
    // 3. Thumb (Cap) - Metallic/3D look
    final thumbY = h - (position * h);
    
    final thumbRect = Rect.fromCenter(
      center: Offset(centerX, thumbY),
      width: 28, // Wider
      height: 48, // Taller
    );
    
    // Beautiful soft drop shadow
    final shadowPath = Path()..addRRect(RRect.fromRectAndRadius(thumbRect, const Radius.circular(4)));
    canvas.drawShadow(shadowPath.shift(const Offset(0, 6)), Colors.black.withOpacity(0.3), 12, true);
    canvas.drawShadow(shadowPath.shift(const Offset(0, 2)), Colors.black.withOpacity(0.15), 4, true);

    // Thumb Body Gradient (Warm Steel vs Dark Steel)
    final List<Color> gradientColors = isDark 
        ? [const Color(0xFF4A443F), const Color(0xFF322C28), const Color(0xFF241F1C)] // Dark steel
        : [const Color(0xFFFDFBF7), const Color(0xFFE8E0D5), const Color(0xFFD5CABB)]; // Light steel

    final paintThumb = Paint()
      ..shader = LinearGradient(
        colors: gradientColors, 
        stops: const [0.0, 0.4, 1.0],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(thumbRect);

    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect, const Radius.circular(4)),
      paintThumb,
    );
    
    // Inner bevel highlight
    final paintHighlight = Paint()
      ..color = isDark ? Colors.white24 : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect.deflate(1), const Radius.circular(3)),
      paintHighlight,
    );
    
    // 4. Glowing Indicator Line
    final centerLineRect = Rect.fromCenter(
      center: Offset(centerX, thumbY),
      width: 18,
      height: 4,
    );
    
    // Indicator Base
    final paintIndicatorBg = Paint()..color = isDark ? Colors.black : const Color(0xFF2A1C16);
    canvas.drawRect(centerLineRect, paintIndicatorBg);

    // Glow Effect
    final paintGlow = Paint()
      ..color = color
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
    canvas.drawRect(centerLineRect.deflate(0.5), paintGlow);

    // Bright Center Let
    final paintIndicatorPulse = Paint()..color = Colors.white.withOpacity(0.8);
    canvas.drawRect(centerLineRect.deflate(1), paintIndicatorPulse);
  }

  @override
  bool shouldRepaint(covariant _FaderPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.color != color;
  }
}

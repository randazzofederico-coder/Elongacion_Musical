import 'dart:math';
import 'package:flutter/foundation.dart' show kIsWeb;
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
  // Local drag state — decouples visual from TrackModel rebuild cascade
  double? _dragVolume;
  bool _isDragging = false;
  double? _cachedHeight;

  // Mapping Constants
  // We map normalized UI position (0.0 bottom to 1.0 top) to Amplitude.
  // Goal: 0.75 position = 0dB (Amplitude 1.0)
  //       1.00 position = +6dB (Amplitude ~2.0)
  
  double _amplitudeToPosition(double amp) {
    if (amp <= 1.0) {
      return 0.75 * sqrt(max(0, amp));
    } else {
      return 0.75 + (amp - 1.0) * 0.25;
    }
  }

  double _positionToAmplitude(double pos) {
    if (pos <= 0.75) {
      final norm = pos / 0.75;
      return norm * norm;
    } else {
      return 1.0 + (pos - 0.75) * 4.0;
    }
  }

  String _amplitudeToDbString(double amp) {
    if (amp <= 0.0001) return "-Inf";
    final db = 20 * log(amp) / ln10;
    return "${db > 0 ? '+' : ''}${db.toStringAsFixed(1)}";
  }

  double get _effectiveVolume => _isDragging ? (_dragVolume ?? widget.volume) : widget.volume;

  void _handleDragStart(DragStartDetails details) {
    _isDragging = true;
    _dragVolume = widget.volume;
  }

  void _handleDrag(double dy, double height) {
    double localY = (height - dy).clamp(0.0, height);
    double pos = localY / height;
    double newAmp = _positionToAmplitude(pos);
    
    _dragVolume = newAmp;
    setState(() {}); // Instant local visual update — no TrackModel cascade
    widget.onChanged(newAmp); // Update audio engine
  }

  void _handleDragEnd() {
    final finalVol = _dragVolume ?? widget.volume;
    _isDragging = false;
    _dragVolume = null;
    widget.onChangeEnd(finalVol);
  }

  void _showValueDialog(BuildContext context) {
    final controller = TextEditingController(text: _amplitudeToDbString(widget.volume).replaceAll(" dB", ""));
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surfaceHighlight(context),
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
    final double effectiveVol = _effectiveVolume;
    final double position = _amplitudeToPosition(effectiveVol);
    final String dbLabel = _amplitudeToDbString(effectiveVol);
    final effectiveColor = widget.color ?? AppColors.accentAmber(context);
    final isDark = AppColors.isDark(context);

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
                fontFamily: 'monospace',
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
              _cachedHeight = h;
              
              return GestureDetector(
                onVerticalDragStart: _handleDragStart,
                onVerticalDragUpdate: (details) {
                  _handleDrag(details.localPosition.dy, h);
                },
                onVerticalDragEnd: (_) => _handleDragEnd(),
                onTapDown: (details) {
                   _handleDrag(details.localPosition.dy, h);
                   widget.onChangeEnd(widget.volume);
                },
                onDoubleTap: () {
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
                    isDark: isDark,
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
    
    // Beautiful soft drop shadow (native only)
    if (!kIsWeb) {
      final shadowPath = Path()..addRRect(RRect.fromRectAndRadius(thumbRect, const Radius.circular(4)));
      canvas.drawShadow(shadowPath.shift(const Offset(0, 6)), Colors.black.withOpacity(0.3), 12, true);
      canvas.drawShadow(shadowPath.shift(const Offset(0, 2)), Colors.black.withOpacity(0.15), 4, true);
    }

    // Thumb Body
    final thumbRRect = RRect.fromRectAndRadius(thumbRect, const Radius.circular(4));
    if (kIsWeb) {
      // Flat color on web — avoids expensive createShader() per frame
      final paintThumb = Paint()
        ..color = isDark ? const Color(0xFF3A342F) : const Color(0xFFE8E0D5);
      canvas.drawRRect(thumbRRect, paintThumb);
    } else {
      // Gradient on native (Warm Steel vs Dark Steel)
      final List<Color> gradientColors = isDark 
          ? [const Color(0xFF4A443F), const Color(0xFF322C28), const Color(0xFF241F1C)]
          : [const Color(0xFFFDFBF7), const Color(0xFFE8E0D5), const Color(0xFFD5CABB)];

      final paintThumb = Paint()
        ..shader = LinearGradient(
          colors: gradientColors, 
          stops: const [0.0, 0.4, 1.0],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ).createShader(thumbRect);
      canvas.drawRRect(thumbRRect, paintThumb);
    }
    
    // Inner bevel highlight
    final paintHighlight = Paint()
      ..color = isDark ? Colors.white24 : Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    canvas.drawRRect(
      RRect.fromRectAndRadius(thumbRect.deflate(1), const Radius.circular(3)),
      paintHighlight,
    );
    
    // 4. Indicator Line
    final centerLineRect = Rect.fromCenter(
      center: Offset(centerX, thumbY),
      width: 18,
      height: 4,
    );
    
    // Indicator Base
    final paintIndicatorBg = Paint()..color = isDark ? Colors.black : const Color(0xFF2A1C16);
    canvas.drawRect(centerLineRect, paintIndicatorBg);

    // Glow Effect — MaskFilter.blur is expensive on web
    if (!kIsWeb) {
      final paintGlow = Paint()
        ..color = color
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4);
      canvas.drawRect(centerLineRect.deflate(0.5), paintGlow);
    } else {
      canvas.drawRect(centerLineRect.deflate(0.5), Paint()..color = color);
    }

    // Bright Center Line
    final paintIndicatorPulse = Paint()..color = Colors.white.withOpacity(0.8);
    canvas.drawRect(centerLineRect.deflate(1), paintIndicatorPulse);
  }

  @override
  bool shouldRepaint(covariant _FaderPainter oldDelegate) {
    return oldDelegate.position != position || oldDelegate.color != color;
  }
}

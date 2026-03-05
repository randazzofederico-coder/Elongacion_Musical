import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StudioHeader extends StatelessWidget {
  final String title;
  final Widget? leading;
  const StudioHeader({super.key, required this.title, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      margin: const EdgeInsets.only(top: 8, left: 16, right: 16, bottom: 8), // Floating margins
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(24), // Pill shape
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Logo / Title
          Row(
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 8),
              ],
              Icon(Icons.equalizer, color: AppColors.accentCyan(context), size: 20),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          
          // Right Side Indicators
          Row(
            children: [
               IconButton(
                 icon: Icon(Icons.settings, color: AppColors.textSecondary(context), size: 20),
                 onPressed: () {
                   Navigator.of(context).push(
                     MaterialPageRoute(
                       builder: (context) => SettingsScreen(
                         settingsService: Provider.of<MixerProvider>(context, listen: false).settingsService,
                       ),
                     ),
                   );
                 },
                 tooltip: 'Settings',
                 padding: EdgeInsets.zero,
                 constraints: const BoxConstraints(),
               ),
            ],
          )
        ],
      ),
    );
  }
}


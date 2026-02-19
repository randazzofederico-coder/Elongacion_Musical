import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:elongacion_musical/screens/settings_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class StudioHeader extends StatelessWidget {
  final String title;
  final bool isOfflineMode;
  final Widget? leading;
  
  const StudioHeader({super.key, required this.title, this.isOfflineMode = false, this.leading});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: const BoxDecoration(
        color: AppColors.surface,
        border: Border(
          bottom: BorderSide(
            color: AppColors.border,
            width: 1,
          ),
        ),
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
              const Icon(Icons.equalizer, color: AppColors.accentCyan, size: 20),
              const SizedBox(width: 8),
              Text(
                title.toUpperCase(),
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.5,
                  fontSize: 14,
                ),
              ),
              const SizedBox(width: 12),
              _StatusIndicator(
                 label: isOfflineMode ? "OFFLINE" : "REALTIME",
                 active: true,
                 color: isOfflineMode ? Colors.orange : AppColors.accentCyan,
              ),
            ],
          ),
          
          // Right Side Indicators
          Row(
            children: [
               IconButton(
                 icon: const Icon(Icons.settings, color: AppColors.textSecondary, size: 20),
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

class _StatusIndicator extends StatelessWidget {
  final String label;
  final bool active;
  final Color color;

  const _StatusIndicator({required this.label, required this.active, this.color = AppColors.accentCyan});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: active ? color.withValues(alpha: 0.1) : Colors.transparent,
        borderRadius: BorderRadius.circular(2),
        border: Border.all(
          color: active ? color.withValues(alpha: 0.3) : Colors.transparent,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
           fontSize: 10,
           fontWeight: FontWeight.bold,
           color: active ? color : Colors.grey,
        ),
      ),
    );
  }
}

import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/models/catalog_model.dart';
import 'package:elongacion_musical/services/catalog_service.dart';
import 'package:elongacion_musical/screens/chapter_screen.dart';
import 'package:elongacion_musical/screens/settings_screen.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class MenuScreen extends StatelessWidget {
  const MenuScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final rhythmChapters = CatalogService.rhythmChapters;
    final instrumentChapters = CatalogService.instrumentChapters;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Elongación Musical'),
        backgroundColor: AppColors.surface,
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: Colors.white70),
            onPressed: () {
              // Access SettingsService via MixerProvider since it holds the reference
              // and is available at the top level
              final settingsService = context.read<MixerProvider>().settingsService;
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (_) => SettingsScreen(settingsService: settingsService),
                ),
              );
            },
          ),
        ],
      ),
      body: SafeArea( // Crucial for Android nav bars
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          children: [
            const _SectionHeader(title: "RITMO"),
            ...rhythmChapters.map((c) => _ChapterCard(chapter: c)),
            
            const SizedBox(height: 24),
            
            const _SectionHeader(title: "INSTRUMENTO"),
            ...instrumentChapters.map((c) => _ChapterCard(chapter: c)),
            
            // Extra padding at bottom to ensure last item is visible above nav bar if translucent
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 4),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.accentCyan,
          fontSize: 20,
          fontWeight: FontWeight.bold,
          letterSpacing: 2.0,
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final Chapter chapter;
  const _ChapterCard({required this.chapter});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        title: Text(
          chapter.title,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        subtitle: Text(
          chapter.description,
          style: const TextStyle(color: Colors.white70),
        ),
        trailing: const Icon(Icons.arrow_forward_ios, color: AppColors.accentCyan, size: 16),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => ChapterScreen(chapter: chapter),
            ),
          );
        },
      ),
    );
  }
}

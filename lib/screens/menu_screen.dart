import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/models/catalog_model.dart';
import 'package:elongacion_musical/services/catalog_service.dart';
import 'package:elongacion_musical/screens/mixer_screen.dart';
import 'package:elongacion_musical/screens/settings_screen.dart';
import 'package:elongacion_musical/providers/mixer_provider.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:elongacion_musical/screens/metronome_screen.dart';

enum ActiveSection { ritmo, instrumento, none }

class MenuScreen extends StatefulWidget {
  const MenuScreen({super.key});

  @override
  State<MenuScreen> createState() => _MenuScreenState();
}

class _MenuScreenState extends State<MenuScreen> {
  ActiveSection _activeSection = ActiveSection.none;
  String? _expandedChapterId;

  void _toggleSection(ActiveSection section) {
    setState(() {
      if (_activeSection == section) {
        _activeSection = ActiveSection.none;
      } else {
        _activeSection = section;
      }
      _expandedChapterId = null; // Close open chapters
    });
  }

  void _toggleChapter(String chapterId) {
    setState(() {
      if (_expandedChapterId == chapterId) {
        _expandedChapterId = null;
      } else {
        _expandedChapterId = chapterId;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final rhythmChapters = CatalogService.rhythmChapters;
    final instrumentChapters = CatalogService.instrumentChapters;

    return Scaffold(
      backgroundColor: AppColors.background(context),
      appBar: AppBar(
        title: const Text('Elongación Musical'),
        backgroundColor: AppColors.surface(context),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.settings, color: AppColors.textPrimary(context)),
            onPressed: () {
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
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          children: [
            _buildMetronomeButton(context),
            const SizedBox(height: 16),
            
            _buildSectionHeader(context, "RITMO", ActiveSection.ritmo),
            _buildChapterList(context, rhythmChapters, ActiveSection.ritmo),
            
            const SizedBox(height: 16),
            
            _buildSectionHeader(context, "INSTRUMENTO", ActiveSection.instrumento),
            _buildChapterList(context, instrumentChapters, ActiveSection.instrumento),
            
            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  Widget _buildMetronomeButton(BuildContext context) {
    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => const MetronomeScreen()));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: AppColors.accentCyan(context), // Usamos el color de acento principal
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: AppColors.accentCyan(context).withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              "METRÓNOMO",
              style: TextStyle(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            Icon(
              Icons.timer,
              color: Colors.white,
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title, ActiveSection section) {
    final isActive = _activeSection == section;
    return GestureDetector(
      onTap: () => _toggleSection(section),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        decoration: BoxDecoration(
          color: isActive ? AppColors.accentCyan(context) : AppColors.surface(context),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: isActive ? AppColors.accentCyan(context).withOpacity(0.3) : Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: TextStyle(
                color: isActive ? Colors.white : AppColors.textPrimary(context),
                fontSize: 22,
                fontWeight: FontWeight.bold,
                letterSpacing: 2.0,
              ),
            ),
            Icon(
              isActive ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: isActive ? Colors.white : AppColors.accentCyan(context),
              size: 28,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChapterList(BuildContext context, List<Chapter> chapters, ActiveSection section) {
    return AnimatedSize(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      child: _activeSection == section
          ? Column(
              children: chapters.map((c) => _buildChapterAccordion(context, c)).toList(),
            )
          : const SizedBox.shrink(),
    );
  }

  Widget _buildChapterAccordion(BuildContext context, Chapter chapter) {
    final isExpanded = _expandedChapterId == chapter.id;
    
    return Container(
      margin: const EdgeInsets.only(bottom: 12, left: 8, right: 8),
      decoration: BoxDecoration(
        color: AppColors.surface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isExpanded ? AppColors.accentCyan(context).withOpacity(0.6) : AppColors.border(context).withOpacity(0.5),
          width: 1.5,
        ),
        boxShadow: isExpanded
            ? [
                BoxShadow(
                  color: AppColors.accentCyan(context).withOpacity(0.1),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                )
              ]
            : [],
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () => _toggleChapter(chapter.id),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    chapter.title,
                    style: TextStyle(
                      color: isExpanded ? AppColors.accentCyan(context) : AppColors.textPrimary(context),
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Icon(
                    isExpanded ? Icons.remove_circle_outline : Icons.add_circle_outline,
                    color: isExpanded ? AppColors.accentCyan(context) : AppColors.textSecondary(context),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: isExpanded
                ? Container(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Column(
                      children: chapter.exercises.map((e) => _buildExerciseTile(context, e)).toList(),
                    ),
                  )
                : const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildExerciseTile(BuildContext context, Exercise exercise) {
    // "dúo" typically has accent, handle both cases
    final titleLower = exercise.title.toLowerCase();
    final isDuo = titleLower.contains('dúo') || titleLower.contains('duo');
    
    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
             builder: (_) => MixerScreen(exercise: exercise),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Row(
          children: [
            Icon(
              isDuo ? Icons.people : Icons.music_note,
              color: AppColors.accentCyan(context).withOpacity(0.8),
              size: 22,
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                exercise.title,
                style: TextStyle(
                  color: AppColors.textPrimary(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.surfaceHighlight(context),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.play_arrow, color: AppColors.accentCyan(context), size: 18),
            ),
          ],
        ),
      ),
    );
  }
}

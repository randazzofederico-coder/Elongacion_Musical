import 'package:elongacion_musical/constants/app_colors.dart';
import 'package:elongacion_musical/models/catalog_model.dart';
import 'package:elongacion_musical/screens/mixer_screen.dart';
import 'package:flutter/material.dart';

class ChapterScreen extends StatelessWidget {
  final Chapter chapter;

  const ChapterScreen({super.key, required this.chapter});

  @override
  Widget build(BuildContext context) {
    final rhythmicExercises = chapter.exercises.where((e) => e.type == ExerciseType.rhythmic).toList();
    final instrumentExercises = chapter.exercises.where((e) => e.type == ExerciseType.instrument).toList();

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(chapter.title),
        backgroundColor: AppColors.surface,
        leading: const BackButton(color: Colors.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(left: 16, right: 16, top: 16, bottom: 48),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (rhythmicExercises.isNotEmpty) ...[
                const _SectionHeader(title: "Ejercicios Rítmicos"),
                ...rhythmicExercises.map((e) => _ExerciseTile(exercise: e)),
                const SizedBox(height: 24),
              ],
              
              if (instrumentExercises.isNotEmpty) ...[
                const _SectionHeader(title: "Ejercicios con Instrumento"),
                ...instrumentExercises.map((e) => _ExerciseTile(exercise: e)),
              ],
            ],
          ),
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
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(
          color: AppColors.accentCyan,
          fontSize: 18,
          fontWeight: FontWeight.bold,
          letterSpacing: 1.1,
        ),
      ),
    );
  }
}

class _ExerciseTile extends StatelessWidget {
  final Exercise exercise;
  const _ExerciseTile({required this.exercise});

  @override
  Widget build(BuildContext context) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          exercise.type == ExerciseType.rhythmic ? Icons.timer : Icons.music_note,
          color: Colors.white54,
        ),
        title: Text(
          exercise.title,
          style: const TextStyle(color: Colors.white),
        ),
        trailing: const Icon(Icons.play_circle_fill, color: AppColors.accentCyan),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
               builder: (_) => MixerScreen(exercise: exercise),
            ),
          );
        },
      ),
    );
  }
}

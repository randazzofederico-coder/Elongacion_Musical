import 'package:elongacion_musical/models/catalog_model.dart';
import 'package:flutter/foundation.dart';

class CatalogService {
  static const List<TrackData> _defaultTracks = [
    TrackData(id: '1', name: 'Ample Bass', assetPath: 'assets/audio/Duo 1/ample_bass.wav'),
    TrackData(id: '2', name: 'Bombo Out', assetPath: 'assets/audio/Duo 1/bombo.wav'),
    TrackData(id: '3', name: 'Fl 1', assetPath: 'assets/audio/Duo 1/fl1.wav'),
    TrackData(id: '4', name: 'Fl 2', assetPath: 'assets/audio/Duo 1/fl2.wav'),
    TrackData(id: '5', name: 'Piano', assetPath: 'assets/audio/Duo 1/piano.wav'),
  ];
  
  // Section 1: RITMO (5 Chapters)
  static List<Chapter> get rhythmChapters {
    return List.generate(5, (index) {
       final num = index + 1;
       final List<Exercise> exercises = List.generate(3, (exIndex) => Exercise(
            id: 'r_c${num}_e$exIndex',
            title: 'Ejercicio ${exIndex + 1}',
            type: ExerciseType.rhythmic,
            tracks: _defaultTracks,
       ));

       return Chapter(
         id: 'ritmo_$num',
         title: 'Capítulo $num',
         description: 'Ejercicios de Ritmo',
         exercises: exercises,
       );
    });
  }

  // Section 2: INSTRUMENTO (10 Chapters)
  static List<Chapter> get instrumentChapters {
     return List.generate(10, (index) {
       final num = index + 1;
       
       if (num == 1 || num == 2) {
         // --- REAL DATA FOR CHAPTERS 1 AND 2 ---
         int numExercises = num == 1 ? 7 : 6;
         return _buildInstrumentChapter(num, numExercises);
       }

       // --- PLACEHOLDER FOR CHAPTERS 3-10 ---
       // Some exercises
       final List<Exercise> exercises = List.generate(3, (exIndex) => Exercise(
            id: 'i_c${num}_e$exIndex',
            title: 'Ejercicio ${exIndex + 1}',
            type: ExerciseType.instrument,
            tracks: _defaultTracks,
       ));
       
       // Plus 1 Duo
       exercises.add(Exercise(
          id: 'i_c${num}_duo', 
          title: 'Dúo', 
          type: ExerciseType.instrument, 
          tracks: _defaultTracks
       ));

       return Chapter(
         id: 'inst_$num',
         title: 'Capítulo $num - Instrumento',
         description: 'Ejercicios con Instrumento',
         exercises: exercises,
       );
    });
  }

  static Chapter _buildInstrumentChapter(int chapterNum, int numExercises) {
    // Standard Exercises (Quartet)
    final List<Exercise> exercises = List.generate(numExercises, (index) {
      final exNum = index + 1;
      
      String getPath(String instrument) {
        String exPrefix = 'Ej';
        if (chapterNum == 1 && exNum == 4) exPrefix = 'Eg';
        if (chapterNum == 2 && exNum == 1) exPrefix = 'EJ';
        return 'assets/audio/capitulo $chapterNum/Capitulo $chapterNum-$exPrefix $exNum-$instrument.wav';
      }

      return Exercise(
        id: 'i_c${chapterNum}_e$index', 
        title: 'Ejercicio $exNum', 
        type: ExerciseType.instrument, 
        bpm: 140,
        timeSignatureNumerator: 3,
        timeSignatureDenominator: 4,
        preWaitMeasures: 1,
        countInMeasures: 2,
        tracks: [
          TrackData(id: 'fl', name: 'Flauta', assetPath: getPath('Fl Solista')),
          TrackData(id: 'pn', name: 'Piano', assetPath: getPath('Piano')),
          TrackData(id: 'cb', name: 'Contrabajo', assetPath: getPath('Contrabajo')),
          TrackData(id: 'bb', name: 'Bombo', assetPath: getPath('Bombo')),
        ]
      );
    });

    // 1 Duo (Quintet with 2 Flutes)
    String getDuoPath(String instrument) => 'assets/audio/capitulo $chapterNum/Capitulo $chapterNum-Duo-$instrument.wav';

    exercises.add(Exercise(
      id: 'i_c${chapterNum}_duo',
      title: 'Dúo',
      type: ExerciseType.instrument,
      bpm: 140,
      timeSignatureNumerator: 3,
      timeSignatureDenominator: 4,
      preWaitMeasures: 1,
      countInMeasures: 2,
      tracks: [
        TrackData(id: 'fl1', name: 'Flauta 1', assetPath: getDuoPath('Fl1')),
        TrackData(id: 'fl2', name: 'Flauta 2', assetPath: getDuoPath('Fl2')),
        TrackData(id: 'pn', name: 'Piano', assetPath: getDuoPath('Piano')),
        TrackData(id: 'cb', name: 'Contrabajo', assetPath: getDuoPath('Contrabajo')),
        TrackData(id: 'bb', name: 'Bombo', assetPath: getDuoPath('Bombo')),
      ]
    ));

    return Chapter(
      id: 'inst_$chapterNum',
      title: 'Capítulo $chapterNum - Instrumento',
      description: 'Ejercicios con Instrumento (Real)',
      exercises: exercises,
    );
  }
  
  static List<Chapter> get allChapters => [...rhythmChapters, ...instrumentChapters];
}

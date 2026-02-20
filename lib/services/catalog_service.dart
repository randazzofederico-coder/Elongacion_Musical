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
       
       if (num == 1) {
         // --- REAL DATA FOR CHAPTER 1 ---
         return _buildChapter1();
       }

       // --- PLACEHOLDER FOR CHAPTERS 2-10 ---
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

  static Chapter _buildChapter1() {
    // 7 Standard Exercises (Quartet)
    final List<Exercise> exercises = List.generate(7, (index) {
      final exNum = index + 1;
      final basePath = 'assets/audio/Instrumento/capitulo_1/ejercicio_$exNum';
      
      return Exercise(
        id: 'i_c1_e$index', 
        title: 'Ejercicio $exNum', 
        type: ExerciseType.instrument, 
        bpm: 140,
        timeSignatureNumerator: 3,
        timeSignatureDenominator: 4,
        preWaitMeasures: 1,
        countInMeasures: 2,
        tracks: [
          TrackData(id: 'fl', name: 'Flauta', assetPath: '$basePath/flauta.wav'),
          TrackData(id: 'pn', name: 'Piano', assetPath: '$basePath/piano.wav'),
          TrackData(id: 'cb', name: 'Contrabajo', assetPath: '$basePath/contrabajo.wav'),
          TrackData(id: 'bb', name: 'Bombo', assetPath: '$basePath/bombo.wav'),
        ]
      );
    });

    // 1 Duo (Quintet with 2 Flutes)
    const duoPath = 'assets/audio/Instrumento/capitulo_1/duo';
    exercises.add(Exercise(
      id: 'i_c1_duo',
      title: 'Dúo',
      type: ExerciseType.instrument,
      bpm: 140,
      timeSignatureNumerator: 3,
      timeSignatureDenominator: 4,
      preWaitMeasures: 1,
      countInMeasures: 2,
      tracks: [
        TrackData(id: 'fl1', name: 'Flauta 1', assetPath: '$duoPath/flauta1.wav'),
        TrackData(id: 'fl2', name: 'Flauta 2', assetPath: '$duoPath/flauta2.wav'),
        TrackData(id: 'pn', name: 'Piano', assetPath: '$duoPath/piano.wav'),
        TrackData(id: 'cb', name: 'Contrabajo', assetPath: '$duoPath/contrabajo.wav'),
        TrackData(id: 'bb', name: 'Bombo', assetPath: '$duoPath/bombo.wav'),
      ]
    ));

    return Chapter(
      id: 'inst_1',
      title: 'Capítulo 1 - Instrumento',
      description: 'Ejercicios con Instrumento (Real)',
      exercises: exercises,
    );
  }
  
  static List<Chapter> get allChapters => [...rhythmChapters, ...instrumentChapters];
}

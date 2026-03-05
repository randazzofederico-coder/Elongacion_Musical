import 'package:elongacion_musical/models/catalog_model.dart';
import 'package:flutter/foundation.dart';

class CatalogService {
  static const List<TrackData> _defaultTracks = [
    TrackData(id: '1', name: 'Flauta', assetPath: ''),
    TrackData(id: '2', name: 'Piano', assetPath: ''),
    TrackData(id: '3', name: 'Contrabajo', assetPath: ''),
    TrackData(id: '4', name: 'Bombo', assetPath: ''),
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
       
       if (num >= 1 && num <= 4) {
         // --- REAL DATA FOR CHAPTERS 1 TO 4 ---
         int numExercises = 3; // default fallback
         if (num == 1) numExercises = 7;
         if (num == 2) numExercises = 6;
         if (num == 3) numExercises = 3;
         if (num == 4) numExercises = 4;
         return _buildInstrumentChapter(num, numExercises);
       }

       // --- PLACEHOLDER FOR CHAPTERS 4-10 ---
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
    // Helper formats:
    // Duo: assets/audio/Con instrumento/Capitulo X/Capitulo X-Duo-Inst.wav
    // Ej: assets/audio/Con instrumento/Capitulo X/Capitulo X-Ej Y-Inst.wav
    String getDuoPath(String instrument) {
      if (chapterNum >= 1 && chapterNum <= 4) {
        return 'assets/audio/Con instrumento/Capitulo $chapterNum M4A/Capitulo $chapterNum-Duo-$instrument.m4a';
      }
      return 'assets/audio/Con instrumento/Capitulo $chapterNum/Capitulo $chapterNum-Duo-$instrument.wav';
    }

    String getPath(int exNum, String instrument) {
      String exPrefix = 'Ej';
      if (chapterNum == 2 && exNum == 1) exPrefix = 'EJ'; // Based on file list 'Capitulo 2-EJ 1-...'
      
      if (chapterNum >= 1 && chapterNum <= 4) {
        // Special case for Chapter 4 Ej 1 where there are 1a and 1b files
        if (chapterNum == 4 && exNum == 1) {
            String suffix = '1a';
            // We'll map Fl2 to 1b, while everything else goes to 1a
            if (instrument == 'Fl2') {
                suffix = '1b';
                instrument = 'Fl Solista'; // The actual file is named "Ej 1b-Fl Solista"
            } else if (instrument == 'Fl1') {
                instrument = 'Fl Solista'; // The actual file is named "Ej 1a-Fl Solista"
            }
            return 'assets/audio/Con instrumento/Capitulo $chapterNum M4A/Capitulo $chapterNum-$exPrefix $suffix-$instrument.m4a';
        }
        return 'assets/audio/Con instrumento/Capitulo $chapterNum M4A/Capitulo $chapterNum-$exPrefix $exNum-$instrument.m4a';
      }
      return 'assets/audio/Con instrumento/Capitulo $chapterNum/Capitulo $chapterNum-$exPrefix $exNum-$instrument.wav';
    }

    // Standard Exercises
    final List<Exercise> exercises = List.generate(numExercises, (index) {
      final exNum = index + 1;
      
      List<TrackData> tracks = [];
      
      // Capitulo 3, Ejercicio 1 and Capitulo 4, Ejercicio 1 have Fl1 & Fl2 instead of Fl Solista
      if ((chapterNum == 3 || chapterNum == 4) && exNum == 1) {
        tracks = [
          TrackData(id: 'fl1', name: 'Flauta 1', assetPath: getPath(exNum, 'Fl1')),
          TrackData(id: 'fl2', name: 'Flauta 2', assetPath: getPath(exNum, 'Fl2')),
          TrackData(id: 'pn', name: 'Piano', assetPath: getPath(exNum, 'Piano')),
          TrackData(id: 'cb', name: 'Contrabajo', assetPath: getPath(exNum, 'Contrabajo')),
          TrackData(id: 'bb', name: 'Bombo', assetPath: getPath(exNum, 'Bombo')),
        ];
      } else {
        tracks = [
          TrackData(id: 'fl', name: 'Flauta', assetPath: getPath(exNum, 'Fl Solista')),
          TrackData(id: 'pn', name: 'Piano', assetPath: getPath(exNum, 'Piano')),
          TrackData(id: 'cb', name: 'Contrabajo', assetPath: getPath(exNum, 'Contrabajo')),
          TrackData(id: 'bb', name: 'Bombo', assetPath: getPath(exNum, 'Bombo')),
        ];
      }

      return Exercise(
        id: 'i_c${chapterNum}_e$index', 
        title: 'Ejercicio $exNum', 
        type: ExerciseType.instrument, 
        bpm: chapterNum == 3 ? 170 : 140,
        timeSignatureNumerator: 3,
        timeSignatureDenominator: 4,
        preWaitMeasures: 1,
        countInMeasures: 2,
        tracks: tracks,
      );
    });

    // 1 Duo per Chapter
    List<TrackData> duoTracks = [
      TrackData(id: 'fl1', name: 'Flauta 1', assetPath: getDuoPath('Fl1')),
      TrackData(id: 'fl2', name: 'Flauta 2', assetPath: getDuoPath('Fl2')),
      TrackData(id: 'cb', name: 'Contrabajo', assetPath: getDuoPath('Contrabajo')),
      TrackData(id: 'bb', name: 'Bombo', assetPath: getDuoPath('Bombo')),
    ];
    
    // Chapter 1 Duo did not have a Piano originally, but the user just added it.
    duoTracks.insert(2, TrackData(id: 'pn', name: 'Piano', assetPath: getDuoPath('Piano')));

    exercises.add(Exercise(
      id: 'i_c${chapterNum}_duo',
      title: 'Dúo',
      type: ExerciseType.instrument,
      bpm: chapterNum == 3 ? 170 : 140,
      timeSignatureNumerator: 3,
      timeSignatureDenominator: 4,
      preWaitMeasures: 1,
      countInMeasures: 2,
      tracks: duoTracks,
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

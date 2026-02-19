
enum ExerciseType {
  rhythmic,
  instrument,
}

class TrackData {
  final String id;
  final String name;
  final String assetPath;

  const TrackData({
    required this.id,
    required this.name,
    required this.assetPath,
  });
}

class Exercise {
  final String id;
  final String title;
  final ExerciseType type;
  final List<TrackData> tracks;

  const Exercise({
    required this.id,
    required this.title,
    required this.type,
    required this.tracks,
  });
}

class Chapter {
  final String id;
  final String title;
  final String description;
  final List<Exercise> exercises;

  const Chapter({
    required this.id,
    required this.title,
    required this.description,
    required this.exercises,
  });
}

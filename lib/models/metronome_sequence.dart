class MetronomeInstance {
  final String id;
  int bpm;
  int cycles; // How many times this pattern repeats
  List<int> pattern34;
  List<int> pattern68;
  
  MetronomeInstance({
    String? id,
    this.bpm = 120,
    this.cycles = 4,
    this.pattern34 = const [1, 0, 0, 0, 0, 0],
    this.pattern68 = const [0, 0, 0, 0, 0, 0],
  }) : id = id ?? DateTime.now().microsecondsSinceEpoch.toString();

  MetronomeInstance copyWith({
    String? id,
    int? bpm,
    int? cycles,
    List<int>? pattern34,
    List<int>? pattern68,
  }) {
    return MetronomeInstance(
      id: id ?? this.id,
      bpm: bpm ?? this.bpm,
      cycles: cycles ?? this.cycles,
      pattern34: pattern34 ?? List.from(this.pattern34),
      pattern68: pattern68 ?? List.from(this.pattern68),
    );
  }
}

class MetronomeSequence {
  List<MetronomeInstance> instances;
  
  MetronomeSequence({List<MetronomeInstance>? instances})
      : instances = instances ?? [];

  void addInstance(MetronomeInstance instance) {
    instances.add(instance);
  }

  void removeInstance(String id) {
    instances.removeWhere((i) => i.id == id);
  }

  void reorder(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final item = instances.removeAt(oldIndex);
    instances.insert(newIndex, item);
  }
}

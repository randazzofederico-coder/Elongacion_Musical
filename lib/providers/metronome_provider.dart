import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:native_audio_engine/live_mixer.dart';

class HomeMetronomePulse {
  List<int> subdivisions;
  HomeMetronomePulse([List<int>? subdivisions]) : subdivisions = subdivisions ?? [0];
}

class HomeMetronomeInstance {
  final int id;
  List<HomeMetronomePulse> pulses;
  double volume;
  bool isMuted;
  bool isSolo;
  String title;
  String structure;

  HomeMetronomeInstance({
    required this.id,
    required this.title,
    this.structure = "4",
    List<HomeMetronomePulse>? pulses,
    this.volume = 0.8,
    this.isMuted = false,
    this.isSolo = false,
  }) : pulses = pulses ?? _parseStructureInitial(structure); 

  static List<HomeMetronomePulse> _parseStructureInitial(String struct) {
      final String cleaned = struct.replaceAll(' ', '');
      if (cleaned.isEmpty) return List.generate(4, (index) => HomeMetronomePulse([index == 0 ? 1 : 3]));
      
      final List<String> parts = cleaned.split('+');
      final List<HomeMetronomePulse> newPulses = [];
      for (String part in parts) {
          int count = 1;
          int subdivision = 1;
          
          if (part.contains('/')) {
              final subParts = part.split('/');
              count = int.tryParse(subParts[0]) ?? 1;
              if (subParts.length > 1) subdivision = int.tryParse(subParts[1]) ?? 1;
          } else {
              count = int.tryParse(part) ?? 1;
          }
          
          if (count <= 0) count = 1;
          if (subdivision <= 0) subdivision = 1;
          
          for (int i = 0; i < count; i++) {
              List<int> subdivList = List.generate(subdivision, (s) => 3); // Subdivisions are 3
              if (i == 0) {
                  subdivList[0] = 1; // Primary pulse head
              } else {
                  subdivList[0] = 2; // Secondary pulse head
              }
              newPulses.add(HomeMetronomePulse(subdivList));
          }
      }
      return newPulses;
  }
}

class MetronomeProvider with ChangeNotifier {
  final LiveMixer _liveMixer = LiveMixer();
  
  bool _isPlaying = false;
  bool get isPlaying => _isPlaying;

  int _bpm = 120;
  int get bpm => _bpm;
  
  final List<HomeMetronomeInstance> _instances = [];
  List<HomeMetronomeInstance> get instances => _instances;

  int _nextId = 1;

  final List<DateTime> _tapTimes = [];

  MetronomeProvider() {
    _initEngine();
  }

  Future<void> _initEngine() async {
    if (kIsWeb) {
      try {
        await (_liveMixer as dynamic).init();
      } catch (e) {
        debugPrint("MetronomeProvider Web Initialization Error: $e");
      }
    }
    
    _liveMixer.setMetronomeSound(0, _generateClickSound(1000.0));
    _liveMixer.setMetronomeSound(1, _generateClickSound(600.0));
    _liveMixer.setMetronomeSound(2, _generateClickSound(800.0));
    _liveMixer.setMetronomeConfig(_bpm);
    _liveMixer.setMasterVolume(1.0);
    _liveMixer.setMetronomePreviewMode(true); // Always isolated preview mode
    
    // Add defaults
    addInstance(title: "Patrón 1", structure: "4");
    addInstance(title: "Patrón 2", structure: "3+2");
  }
  
  void addInstance({required String title, String structure = "4", List<HomeMetronomePulse>? pulses}) {
    final instance = HomeMetronomeInstance(id: _nextId++, title: title, structure: structure, pulses: pulses);
    _instances.add(instance);
    
    final flatPattern = <int>[];
    final subdivisions = <int>[];
    for (var pulse in instance.pulses) {
        subdivisions.add(pulse.subdivisions.length);
        flatPattern.addAll(pulse.subdivisions);
    }
    
    _liveMixer.addMetronomePattern(
        instance.id, 
        flatPattern,
        subdivisions,
        instance.volume, 
        instance.isMuted, 
        instance.isSolo
    );
    notifyListeners();
  }
  
  void removeInstance(int id) {
    _instances.removeWhere((i) => i.id == id);
    _liveMixer.removeMetronomePattern(id);
    notifyListeners();
  }
  
  void updateInstancePulses(int id, List<HomeMetronomePulse> pulses) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.pulses = pulses;
     _syncInstanceToEngine(instance);
     notifyListeners();
  }

  void addPulse(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.pulses.add(HomeMetronomePulse([0])); // Add empty beat
     _syncInstanceToEngine(instance);
     notifyListeners();
  }

  void removePulse(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     if (instance.pulses.length > 1) {
         instance.pulses.removeLast();
         _syncInstanceToEngine(instance);
         notifyListeners();
     }
  }
  
  void updateInstanceStructure(int id, String structureString) {
      final String cleaned = structureString.replaceAll(' ', '');
      if (cleaned.isEmpty) return;

      final List<String> parts = cleaned.split('+');
      final List<HomeMetronomePulse> newPulses = [];

      for (String part in parts) {
          int count = 1;
          int subdivision = 1;
          
          if (part.contains('/')) {
              final subParts = part.split('/');
              count = int.tryParse(subParts[0]) ?? 1;
              if (subParts.length > 1) subdivision = int.tryParse(subParts[1]) ?? 1;
          } else {
              count = int.tryParse(part) ?? 1;
          }
          
          if (count <= 0) count = 1;
          if (subdivision <= 0) subdivision = 1;

          for (int i = 0; i < count; i++) {
              List<int> subdivList = List.generate(subdivision, (s) => 3); // Subdivisions are 3
              if (i == 0) {
                  subdivList[0] = 1; // Primary pulse head
              } else {
                  subdivList[0] = 2; // Secondary pulse head
              }
              newPulses.add(HomeMetronomePulse(subdivList));
          }
      }

      final instance = _instances.firstWhere((i) => i.id == id);
      instance.structure = cleaned;
      instance.pulses = newPulses;
      _syncInstanceToEngine(instance);
      notifyListeners();
  }
  
  void updateInstanceVolume(int id, double volume) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.volume = volume;
     _syncInstanceToEngine(instance);
     notifyListeners();
  }
  
  void toggleInstanceMute(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.isMuted = !instance.isMuted;
     _syncInstanceToEngine(instance);
     notifyListeners();
  }
  
  void toggleInstanceSolo(int id) {
     final instance = _instances.firstWhere((i) => i.id == id);
     instance.isSolo = !instance.isSolo;
     _syncInstanceToEngine(instance);
     notifyListeners();
  }
  
  void _syncInstanceToEngine(HomeMetronomeInstance instance) {
      final flatPattern = <int>[];
      final subdivisions = <int>[];
      for (var pulse in instance.pulses) {
          subdivisions.add(pulse.subdivisions.length);
          flatPattern.addAll(pulse.subdivisions);
      }
      
      _liveMixer.updateMetronomePattern(
         instance.id, 
         flatPattern, 
         subdivisions,
         instance.volume, 
         instance.isMuted, 
         instance.isSolo
      );
  }

  void updateBPM(int newBpm) {
    _bpm = newBpm.clamp(1, 999);
    _liveMixer.setMetronomeConfig(_bpm);
    notifyListeners();
  }

  void tapTempo() {
    final now = DateTime.now();
    
    // Ignore stales: If it's been more than 2 seconds since the last tap, start fresh
    if (_tapTimes.isNotEmpty && now.difference(_tapTimes.last).inSeconds > 2) {
      _tapTimes.clear();
    }
    
    _tapTimes.add(now);
    
    if (_tapTimes.length > 4) {
      _tapTimes.removeAt(0);
    }
    
    if (_tapTimes.length >= 2) {
      final intervals = <int>[];
      for (int i = 1; i < _tapTimes.length; i++) {
        intervals.add(_tapTimes[i].difference(_tapTimes[i - 1]).inMilliseconds);
      }
      
      final avgInterval = intervals.reduce((a, b) => a + b) / intervals.length;
      if (avgInterval > 0) {
        int newBpm = (60000 / avgInterval).round();
        updateBPM(newBpm);
      }
    }
  }

  void togglePlay() {
    if (_isPlaying) {
      stop();
    } else {
      play();
    }
  }

  void play() {
    _isPlaying = true;
    _liveMixer.seek(0);
    _liveMixer.startPlayback();
    notifyListeners();
  }

  void stop() {
    _isPlaying = false;
    _liveMixer.stopPlayback();
    _liveMixer.seek(0);
    notifyListeners();
  }

  Float32List _generateClickSound(double freq) {
      final int sampleRate = 44100;
      final double durationFreq = 0.05; // 50ms click
      final int samples = (sampleRate * durationFreq).toInt();
      final Float32List buffer = Float32List(samples);
      
      for (int i = 0; i < samples; i++) {
          final double t = i / sampleRate;
          final double envelope = exp(-i / (samples * 0.2)); 
          buffer[i] = (sin(2 * pi * freq * t) * envelope * 0.5); 
      }
      return buffer;
  }

  // --- MACRO CYCLE MATH ---
  int _gcd(int a, int b) {
    while (b != 0) {
      int t = b;
      b = a % b;
      a = t;
    }
    return a;
  }

  int _lcm(int a, int b) {
    if (a == 0 || b == 0) return 0;
    return ((a * b) / _gcd(a, b)).floor();
  }

  int get macroCycleBeats {
    if (_instances.isEmpty) return 4;
    return _instances.map((i) => i.pulses.length).fold(_instances.first.pulses.length, (a, b) => _lcm(a, b));
  }

  double get currentMacroProgress {
    if (!_isPlaying && _liveMixer.getAtomicPosition() == 0) return 0.0;
    
    double framesPerBeat = (44100.0 * 60.0) / _bpm;
    int pos = _liveMixer.getAtomicPosition();
    double currentBeatInTotal = pos / framesPerBeat;
    
    int macroBeats = macroCycleBeats;
    double progress = (currentBeatInTotal % macroBeats) / macroBeats;
    
    return progress;
  }

  @override
  void dispose() {
    _liveMixer.dispose();
    super.dispose();
  }
}

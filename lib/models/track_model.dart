import 'package:flutter/foundation.dart';

class TrackModel extends ChangeNotifier {
  final String id;
  final String name;
  final String assetPath;
  
  double _volume;
  double get volume => _volume;
  set volume(double value) {
    if (_volume != value) {
      _volume = value;
      notifyListeners();
    }
  }

  double _pan; // -1.0 (Left) to 1.0 (Right)
  double get pan => _pan;
  set pan(double value) {
    if (_pan != value) {
      _pan = value;
      notifyListeners();
    }
  }

  bool _isMuted;
  bool get isMuted => _isMuted;
  set isMuted(bool value) {
    if (_isMuted != value) {
      _isMuted = value;
      notifyListeners();
    }
  }

  bool _isSolo = false;
  bool get isSolo => _isSolo;
  set isSolo(bool value) {
    if (_isSolo != value) {
      _isSolo = value;
      notifyListeners();
    }
  }

  // PCM Data: List of channels, each containing samples
  List<Float32List>? samples;
  
  // Visualization Data: List of channels, each containing downsampled peaks (0.0 to 1.0)
  List<List<double>> waveformData = [];
  
  // Format info
  int? sampleRate;

  TrackModel({
    required this.id,
    required this.name,
    required this.assetPath,
    double volume = 1.0,
    double pan = 0.0,
    bool isMuted = false,
  }) : _volume = volume,
       _pan = pan,
       _isMuted = isMuted;     
}

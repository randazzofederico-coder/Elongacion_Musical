import 'dart:math';
import 'package:elongacion_musical/models/track_model.dart';

List<List<double>> generateMasterWaveform(List<TrackModel> tracks, String? soloTrackId) {
    if (tracks.isEmpty) {
       return [];
    }
    
    // Assume all tracks roughly same length/points?
    // We'll use the first track's length as reference or max length.
    int points = 0;
    for (var t in tracks) {
      if (t.waveformData.isNotEmpty) {
        points = max(points, t.waveformData[0].length);
      }
    }
    
    if (points == 0) return [];
    
    // Initialize Master L and R
    List<double> masterL = List.filled(points, 0.0);
    List<double> masterR = List.filled(points, 0.0);
    
    List<TrackModel> activeTracks = tracks;
    
    // Handle Solo
    if (soloTrackId != null) {
      activeTracks = activeTracks.where((t) => t.id == soloTrackId).toList();
    }

    for (var track in activeTracks) {
      if (track.isMuted) continue;
      if (track.waveformData.isEmpty) continue;

      double vol = track.volume;
      double pan = track.pan;
      
      double lGain = 1.0;
      double rGain = 1.0;
      
      if (pan > 0) lGain = 1.0 - pan;
      if (pan < 0) rGain = 1.0 + pan;
      
      bool isStereo = track.waveformData.length > 1;
      int trackPoints = track.waveformData[0].length;
      
      for (int i = 0; i < points && i < trackPoints; i++) {
        if (isStereo) {
           masterL[i] += track.waveformData[0][i] * vol * lGain;
           masterR[i] += track.waveformData[1][i] * vol * rGain;
        } else {
           double val = track.waveformData[0][i];
           masterL[i] += val * vol * lGain;
           masterR[i] += val * vol * rGain;
        }
      }
    }
    
    // Normalize / Clamp?
    // Let's soft clamp to 1.0 for visuals
    for (int i = 0; i < points; i++) {
       if (masterL[i] > 1.0) masterL[i] = 1.0;
       if (masterR[i] > 1.0) masterR[i] = 1.0;
    }

    return [masterL, masterR];
}

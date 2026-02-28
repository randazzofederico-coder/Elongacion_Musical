import 'dart:math';
import 'package:elongacion_musical/models/track_model.dart';

List<List<double>> generateMasterWaveform(
    List<TrackModel> tracks, {
    int? bpm,
    double metronomeVol34 = 0.0,
    double metronomeVol68 = 0.0,
    List<int>? pattern34,
    List<int>? pattern68,
}) {
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
    
    bool anySolo = tracks.any((t) => t.isSolo);
    
    for (var track in tracks) {
      // Solo-in-place logic
      if (anySolo) {
         if (!track.isSolo) continue;
      } else {
         if (track.isMuted) continue;
      }
      
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
    
    // Add Synthetic Metronome Clicks if active
    if (bpm != null && bpm > 0 && (metronomeVol34 > 0 || metronomeVol68 > 0)) {
        // Find total duration to sample
        // Assumes 100 points per second (from WavParser)
        final double pointsPerSecond = 100.0; 
        final double secondsPerBeat = 60.0 / bpm;
        final double secondsPerEighth = secondsPerBeat / 2.0;
        final double pointsPerEighth = secondsPerEighth * pointsPerSecond;
        
        for (int i = 0; i < points; i++) {
            double currentEighthFloat = i / pointsPerEighth;
            int currentEighth = currentEighthFloat.floor();
            
            // Check if we are at the exact point of a click
            // The synthetic click is very short, maybe 5 points wide (50ms)
            double distanceToEighth = currentEighthFloat - currentEighth;
            
            if (distanceToEighth < 0.15) { // Visual width of the click (0.15 of an eighth)
                int measurePos = (currentEighth % 6 + 6) % 6;
                
                int type34 = pattern34 != null && pattern34.length > measurePos ? pattern34[measurePos] : 0;
                int type68 = pattern68 != null && pattern68.length > measurePos ? pattern68[measurePos] : 0;
                
                double vol = 0.0;
                if (metronomeVol34 > 0.0 && type34 > 0) {
                    vol = max(vol, metronomeVol34);
                }
                if (metronomeVol68 > 0.0 && type68 > 0) {
                    vol = max(vol, metronomeVol68);
                }
                
                if (vol > 0.0) {
                    // Spike the waveform
                    masterL[i] += vol;
                    masterR[i] += vol;
                }
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

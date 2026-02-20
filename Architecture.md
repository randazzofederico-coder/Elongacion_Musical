# PROYECTO: Elongación Musical (App Multipista Educativa)

## 1. TECH STACK & DEPENDENCIAS
- **Framework:** Flutter (Dart).
- **Audio Engine:** `just_audio` (multi-platform), `just_audio_windows` (Windows).
- **Native Plugin:** `native_audio_engine` (C++ with SoundTouch, local patches for Windows).
- **State Management:** `Provider`.
- Assets: Archivos MP3/WAV locales ubicados en `assets/audio/`.

## 1.1 VERSION CONTROL
- **Repository:** [GitHub - Elongacion_Musical](https://github.com/randazzofederico-coder/Elongacion_Musical.git)
- **Branch Strategy:** `master` (Protected/Main).
- **Status:** Connected and synced (Feb 2026).

## 1.2 CURRENT APP STATE And OBJECTIVES
> [!NOTE]
> **Current Focus:** Codebase Optimization & Stability.

- **Objective:** Ensure all large files are refactored into smaller, maintainable modules (< 200 lines). Verification of native C++ Mixer stability on Windows/Android.
- **Actual State:**
  - Refactoring Complete: `MixerScreen`, `AudioManager`, `MixerStreamSource`, `WaveformSeekBar`, `TrackStrip`.
  - Native Mixer: Implemented and active (`MixerStreamSource`).
  - Audio Engine: `just_audio` + C++ mix loop working.
  - Architecture: Modularized with `utils/` and `widgets/mixer/`.
  - **Optimizations (Feb 2026):**
    - **Memory:** Switched internal audio pipeline to `Float32` (50% RAM reduction).
    - **Glitch Fix:** Removed artificial pacing barriers; engine now feeds player on demand.
    - **Seek:** Instant response via `AudioLoadConfiguration` (400ms buffer).
  - **Runtime Stability:** Android Asset Loading (rootBundle) & Background Waveform Generation fixed.

## 1.1 TESTING FOCUS & PLATFORM STRATEGY (CRITICAL)
> [!IMPORTANT]
> **CURRENT TESTING FOCUS: ANDROID (TABLET & PHONE)**.
> All development and verification should prioritize the Android experience, specifically:
> - Low Latency audio response.
> - Touch interactions (Faders, Knobs).
> - Screen real estate usage (SafeArea, Navigation Bars).

### Platform-Specific Audio Engines
- **Android / iOS:**
  - **Goal:** Real-time performance, low latency (~40ms-100ms).
  - **Implementation:**
    - **Buffer:** `AudioLoadConfiguration` set to **400ms** (Instant Seek).
    - **Pacing:** Removed "Smart Pacing" (Sleeps); relying on `just_audio` pull-request frequency.
    - **Latency Compensation:** Calculated `latencyHint` (Buffer + ~100ms Hardware) passed to UI.
  - **Status:** **ACTIVE TESTING**.
- **Windows / Desktop:**
  - **Goal:** Stability over speed.
  - **Implementation:** Relaxed pacing, larger buffers (~4s latency) to prevent driver underruns.
  - **Status:** **FUTURE / ON HOLD**. Do not optimize for Windows at the expense of Android.

## 2. ESTRUCTURA DE CARPETAS
### Assets de Audio (Data Catalog)
Estructura jerárquica para evitar conflictos de nombres y permitir carga dinámica.
- `assets/audio/instrumento/capitulo_N/ejercicio_M/`
  - Archivos: `flauta.wav`, `piano.wav`, `contrabajo.wav`, `bombo.wav`.
  - **Convención:**
    - `piano.wav`: **STEREO** (Mantener espacialidad).
    - Resto: **MONO** (Para ahorrar espacio y CPU).
- `assets/audio/instrumento/capitulo_N/duo/`
  - Archivos: `flauta1.wav`, `flauta2.wav`, `piano.wav`, `contrabajo.wav`, `bombo.wav`.

### Navegación (Nueva Arquitectura)
- **MenuScreen:** Lista principal dividida en secciones (Ritmo vs Instrumento).
- **ChapterScreen:** Detalle del capítulo con lista de ejercicios.
- **MixerScreen:** "Motor" de reproducción, se instancia con un `Exercise` específico.

```
lib/
├── models/
│   ├── catalog_model.dart     # Definición de Chapter, Exercise, TrackData.
│   └── track_model.dart       # Estado volátil de la pista (Volumen, Pan, Mute).
├── services/
│   ├── audio_manager.dart     # Gestión de alto nivel. Delega análisis a utils.
│   └── mixer_stream_source.dart # Motor de mezcla nativo.
├── providers/
│   └── mixer_provider.dart    # ViewModel principal.
├── utils/
│   ├── audio_analysis_utils.dart # (New) Lógica de decodificación y picos.
│   ├── mixer_utils.dart          # (New) Inicialización de pistas nativas.
│   ├── wav_header_utils.dart     # (New) Generación de headers WAV.
│   └── waveform_utils.dart       # (New) Generación de onda master.
├── constants/
│   └── app_colors.dart        # Paleta de colores "Dark Studio".
├── screens/
│   └── mixer_screen.dart      # Pantalla principal (Layout de alto nivel).
└── widgets/
    ├── mixer/                 # (New) Componentes de la Mixer Screen.
    │   ├── track_list_section.dart
    │   ├── master_section.dart
    │   ├── transport_section.dart
    │   └── track_controls.dart   # (New) Controles de pista (Fader, Knob, Mute/Solo).
    ├── waveform/              # (New) Componentes de visualización.
    │   └── waveform_painter.dart # (New) Logic de pintado de ondas.
    ├── studio_header.dart     # Header customizado.
    ├── track_strip.dart       # Layout del canal individual.
    ├── master_strip.dart      # Layout del canal master.
    ├── vertical_waveform.dart # Visualizador de onda vertical.
    ├── fader_control.dart     # Slider customizado.
    ├── knob_control.dart      # Control rotatorio.
    └── waveform_seek_bar.dart # Barra de navegación (ahora usa WaveformPainter).
```

## 3. ENGINE DE AUDIO (Native C++ Mixer)
## 3. ENGINE DE AUDIO (Native Audio Engine)
- **Core:** `native_audio_engine` (Miniaudio + Custom Phase Vocoder / KissFFT + C++ Logic).
- **Playback Strategy:** `MixerStreamSource` delegates control to `LiveMixer`.
  - **Status:** **ACTIVE**. Mixing, Time-Stretching, and Timing are handled exclusively by C++.
  - **Data Path:** `Float32` optimized. WAV -> Memory -> FFI -> C++ `LiveMixer`.
  - **Mixer Pipeline:** `Tracks` -> `Summing` -> `Vocoder (Time Stretch)` -> `Miniaudio Output`.
- **Timing & Synchronization (The "Atomic Clock"):**
  - **Source of Truth:** An atomic frame counter in the C++ audio callback.
  - **UI Sync:** Dart polls this atomic counter at 60fps via `Ticker` in `WaveformSeekBar`.
  - **Playhead:** Reflects exactly what samples are being sent to the DAC (hardware compensated).
- **Time Stretching (SoundTouch Engine):**
  - **Implementation:** Reverted to the highly optimized `SoundTouch` library (C++) from the experimental Phase Vocoder, significantly lowering CPU footprint.
  - **Efficiency:** Zero-copy processing. Audio buffer stays in C++ memory. Compiled with advanced DSP flags (`-O3`, `-ffast-math`) on Android to prevent CPU starvation in real-time.
  - **Control:** `setSpeed()` updates tempo in real-time.
  - **Tuning UI:** Added debug sliders to the Settings screen to expose WSOLA parameters (`Sequence`, `SeekWindow`, `AAFilter Length`), allowing the user to mitigate "metallic" artifacts depending on the audio source (rhythmic vs melodic).
- **Audio Tools:**
  - `tool/convert_to_mono.dart`: Script utilitario para convertir recursivamente todos los archivos de una carpeta a MONO, *excepto* `piano.wav`.
    - Usage: `dart tool/convert_to_mono.dart`

### 3.1 ENGINE MODES & PLATFORM SPECIFICS
- **Realtime Mode (Default):**
  - Uses `MixerStreamSource` for just-in-time mixing.
  - **Android/iOS:** Optimized for **Low Latency**. 
    - `AudioManager` uses small buffer config (min ~500ms).
    - `MixerStreamSource` uses tight pacing (hard limit ~2.0s).
    - Result: Instant response to Fader/Mute/Solo changes.
  - **Windows/Desktop:** Optimized for **Stability**.
    - `AudioManager` uses larger default buffers.
    - `MixerStreamSource` uses larger internal chunks.
    - Result: Latency is higher to prevent playback stalls.
- **Safe Mode (Offline Rendering):**
  - **Architecture:** `AudioRenderer` class uses `AudioProcessor` (Legacy Dart wrapper) to render. *Note: Need to verify if this is still compatible with new Native structure.*

## 4. UI / UX ("Dark Studio" Aesthetic)
### A. Layout Responsivo & Performance
- **Visual Integration:** Unificación bajo un tema oscuro (`#121212`) simulando hardware (DAW/Consola).
- **Studio Header:** Barra de estado superior integrada, reemplazando la AppBar nativa.
- **Transport Panel:** Control de transporte inferior integrado en el chasis, sin tarjetas flotantes.
- **Split-UI Pattern:** Separación de componentes estáticos (`TrackListSection`) de dinámicos (`MasterSection`).
  - `TrackListSection`: Solo se reconstruye ante cambios estructurales (Reorder, Mute/Solo).
  - `MasterSection`: Se reconstruye 60fps con el `positionStream` para el medidor y seekbar.
- **Auto-Fit:** Los canales se ajustan automáticamente al ancho de pantalla disponible.
- **Pixel-Perfect Alignment:** El Fader del Master alinea exactamente con los Faders de canal.
- **Grid:** Estructura visual clara: Header -> Waveform -> Pan -> Fader -> Mute/Solo.

### B. Componentes Avanzados
- **WaveformSeekBar (New):**
  - **Visualization:** Draws the Master Mix waveform as a background.
  - **Interaction:**
    - **Tap/Slide:** Seek playback position.
    - **Hold (Long Press):** Grab Loop Handles (Start/End) to adjust loop region.
  - **Feedback:** Haptic feedback when grabbing handles.
- **Long-Throw Faders:** Control preciso de volumen con escala dB.
- **Panning:** Distribución estéreo L/R real.

### C. Responsive & Adaptive Layout (Mobile Optimization)
- **Conditional Waveform Display:**
  - **Desktop/Tablet (> 600px):** Shows full vertical waveform and comfortable fader width.
  - **Mobile (< 600px):** Hides waveforms to prioritize fader control access.
  - **User Preference:** Can be toggled manually via Settings.
- **Adaptive Strip Widths:**
  - Calculates exact width per strip to fit **all active tracks + master** within the screen width.
  - Ensures a minimum of 6 faders (5 Tracks + 1 Master) are visible without scrolling on standard mobile devices.
  - Accounts for specific margins (Track: 4px, Master: 8px) to prevent horizontal overflow.
- **Adaptive Landscape Mode (Smart Layout):**
  - **Detection:** Active when screen height < 500px (e.g., Landscape Phone).
  - **Transformation:** Automatically replaces vertical Volume Faders with compact **Volume Knobs**.
  - **Goal:** Preserves usability in short vertical spaces without requiring scrolling.
- **Dynamic Typography:**
  - Track titles automatically adjust font size (10px -> 8px) and letter spacing based on available strip width (< 50px).
  - Uses `TextOverflow.ellipsis` for graceful truncation on extremely narrow screens.

### D. Settings & Preferences
- **Service:** `SettingsService` persists user choices via `SharedPreferences`.
- **Features:**
  - **Show Waveforms:** Toggles track visualization for performance/preference.
  - **Lock Portrait:** Enforces portrait orientation on supported devices (Mobile/Tablet).
  - **Audio Engine Mode:** Toggles between Realtime and Offline rendering.

## 6. PERFORMANCE & OPTIMIZATION
- **Parallel Audio Analysis (Isolates):**
  - Decoding WAV files and calculating waveform peaks is offloaded to a background isolate using `compute`.
  - Prevents UI freeze during heavy track loading.
  - Data transfer optimized using `Map<String, dynamic>` to avoid custom object serialization overhead.
- **Granular UI Updates:**
  - `TrackModel` extends `ChangeNotifier` to notify listeners only when its specific properties (volume, pan, mute) change.
  - `MixerProvider` manages the list structure but delegates property updates to the tracks themselves, preventing global list rebuilds.
- **Granular Waveform Caching:**
  - The Master Waveform used in `WaveformSeekBar` is cached in `MixerProvider` and only recalculated when Track volume/mute/pan changes committed.

## 7. KNOWN ISSUES & LIMITATIONS
- **Specific Audio Glitch (00:08 - 00:10):** [RESOLVED]
  - **Solution:** The artificial "Smart Pacing" logic (`Future.delayed`) was fighting `just_audio`'s internal buffer logic. Removing the pacing and letting the player pull data naturally eliminated the glitch.
- **Play Head Synchronization:** [ACTIVE]
  - **Issue:** The visual cursor sometimes drifts or lags behind the audio (approx 200-500ms).
  - **Cause:** `just_audio.position` reports the time of the *next buffer to be played*, not the *currently hearing* sample.
  - **Mitigation:** Applied a "Calculated Latency Compensation" (`latencyHint`) to `MixerStreamSource`.
  - **Status:** Improved but inconsistent. Requires architectural review (Native Timestamp Querying).
- **Phase Vocoder CPU Stalling (Crackling):** [RESOLVED]
  - **Issue:** Severe audio dropouts, silence, and "chisporroteos" when time-stretching is active on mobile.
  - **Cause:** The custom Transient-Preserving Phase Vocoder, or unoptimized C++ builds, caused CPU starvation.
  - **Mitigation:** Reverted to `SoundTouch` and forced maximum compiler optimization (`-O3` and `-ffast-math`) in Android's `CMakeLists.txt`, resolving the starvation issue entirely.
- **Loop Latency:** Dramatically improved with Native Mixing, though minor artifacts may persist at very tight loop boundaries depending on OS scheduling.
- **Portrait Lock Failure (Android Tablet):** The `SystemChrome.setPreferredOrientations` call is currently ineffective on the test device (TB520FU).
- **Landscape UI on Mobile:** While functional via "Adaptive Landscape Mode" (Knobs), the UI density is high.
- **Seek Bar Interaction:** Handle dragging requires precision. "Hold to drag" improves this but can still be refined.


## 8. FUTURE ROADMAP / PENDING TASKS
- **Loop Logic Review:** [DONE] Verify edge cases in C++ looping and ensure UI sync is perfect. (Implemented Sync Map).
- **Seek Latency:** Improve seek responsiveness. currently `MixerStreamSource` buffering might cause slight delay.
- **Audio Stability:** Investigate intermittent artifacts (clicks/pops) reported during testing. robustecer estabilidad.
- **High-Quality Time Stretching Rewrite:** [ON HOLD]
  - **Status:** We have successfully integrated and optimized SoundTouch. The immediate goal is tuning it via the new UI. 
  - **Future:** If SoundTouch artifacts cannot be tuned away, we will evaluate:
    - Integrating `RubberBand Library` (If GPL licensing permits for the project).
    - Purchasing a commercial license for `élastique` or `Superpowered`.
- **Export:** Renderizado offline de la mezcla final a archivo de audio.
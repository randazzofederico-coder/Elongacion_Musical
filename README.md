<p align="center">
  <h1 align="center">🎵 Elongación Musical</h1>
  <p align="center">
    <strong>Aplicación multipista educativa para músicos</strong><br/>
    Práctica interactiva con mezcla en tiempo real, metrónomo dinámico y motor de audio nativo C++.
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/Flutter-3.10+-02569B?logo=flutter&logoColor=white" alt="Flutter"/>
    <img src="https://img.shields.io/badge/Dart-3.10+-0175C2?logo=dart&logoColor=white" alt="Dart"/>
    <img src="https://img.shields.io/badge/C++-17-00599C?logo=cplusplus&logoColor=white" alt="C++"/>
    <img src="https://img.shields.io/badge/Platforms-Android%20%7C%20Windows%20%7C%20Web-orange" alt="Platforms"/>
    <img src="https://img.shields.io/badge/Version-1.0.0-green" alt="Version"/>
  </p>
</p>

---

## 📖 Descripción

**Elongación Musical** es una aplicación de práctica musical diseñada para estudiantes e instrumentistas que desean mejorar sus habilidades rítmicas y de ensamble. Funciona como una **consola de mezcla multipista** donde cada instrumento de un ejercicio puede controlarse de forma independiente (volumen, paneo, mute, solo), permitiendo al usuario aislar partes, variar velocidades sin alterar la afinación, y crear loops de secciones específicas.

La aplicación está potenciada por un **motor de audio nativo en C++** personalizado que garantiza reproducción de baja latencia y sincronización precisa a nivel de muestra (sample-accurate).

---

## ✨ Características Principales

### 🎚️ Consola de Mezcla Profesional
- **Faders de volumen** verticales por pista con visualización en tiempo real.
- **Knobs de paneo** (Pan L/R) para posicionamiento estéreo independiente.
- **Mute / Solo** por pista para aislar instrumentos específicos.
- **Master Fader** con control de volumen global.
- Diseño tipo "Warm Premium Studio" que emula hardware analógico clásico.

### 🔊 Motor de Audio Nativo (C++)
- Pipeline de mezcla: `Pistas → Master Fader → Routing de Stems → Time Stretch (SoundTouch) → Salida Miniaudio`.
- **Zero-Copy Playback:** Audio decodificado a Float32 en RAM; sin copias intermedias durante la reproducción.
- **Latencia ultra-baja:** Stream de audio "siempre encendido" (hot); Play/Pause instantáneo sin delays de inicialización de hardware.
- **Pop Prevention:** Envolvente de fade interpolado de 20ms en cada cambio dinámico de volumen (Mute/Solo/Play/Pause/Seek).
- **Time Stretching** en tiempo real vía SoundTouch (C++), compilado con optimizaciones DSP máximas (`-O3 -ffast-math`).

### 🥁 Metrónomo Dinámico Analítico
- **Oscilador por software** generado matemáticamente en C++ (sin archivos `.wav` pre-renderizados).
- **Estructuras asimétricas** definibles por el usuario (ej: `3+2`, `2+2+3`).
- **Subdivisiones fraccionarias** (ej: `1/3+2`) para patrones complejos.
- **Múltiples instancias** simultáneas, cada una con su propio grid de secuenciador.
- **Teclado virtual personalizado** para edición de estructuras métricas.
- **Tap Tempo** con promedio de los últimos 4 golpes.
- **Visualización de Macro Ciclo:** Calcula el MCM (Mínimo Común Múltiplo) de todos los patrones y muestra una barra global animada a 60fps.

### 📊 Visualización de Forma de Onda
- Waveform del master renderizado en `CustomPaint`.
- **Pinch-to-Zoom** multi-touch de 1x a 50x.
- **Loop Ruler** interactivo con selección visual de rangos de repetición.
- Recorte de canvas (`ClipRect`) para prevenir desbordamientos visuales.

### 📚 Currículo Estructurado
- **Sección Ritmo:** 5 capítulos con ejercicios rítmicos progresivos.
- **Sección Instrumento:** 10 capítulos (4 completos con audio real + 6 en desarrollo).
  - Cada capítulo contiene: Ejercicios individuales + 1 Dúo.
  - Instrumentos: Flauta (solista o 1/2), Piano, Contrabajo, Bombo.
  - Indicaciones de tiempo: 3/4, BPM 140 (Cap. 1, 2, 4) / 170 (Cap. 3).

### 🎨 Diseño y UX
- **Light/Dark Mode** dinámico con paleta "Warm Studio" (tonos cálidos en ámbar, naranja, crema).
- **Responsiveness total:** Layout adaptativo que oculta waveforms en pantallas < 600px.
- **Orientación forzada:** Portrait para experiencia de consola de mezcla predecible.
- **Persistencia de ajustes** por ejercicio: volúmenes, panes, mutes, rangos de loop, modo oscuro (via `SharedPreferences`).

---

## 🏗️ Arquitectura

```
lib/
├── constants/
│   └── app_colors.dart            # Sistema de colores dinámico (Light/Dark)
├── models/
│   ├── catalog_model.dart         # Chapter, Exercise, TrackData
│   └── metronome_sequence.dart    # MetronomeInstance, MetronomeSequence
├── providers/
│   ├── mixer_provider.dart        # Facade principal, coordinador de estado
│   ├── playback_provider.dart     # Play, Seek, Loop
│   ├── track_list_provider.dart   # Volúmenes, Mute, Solo por pista
│   ├── mixer_settings_provider.dart # Ajustes del engine y UI
│   ├── metronome_provider.dart    # Estado y lógica del metrónomo
│   └── theme_provider.dart        # Light/Dark mode global
├── services/
│   ├── audio_manager.dart         # Coordinador de playback y FFI
│   ├── mixer_stream_source.dart   # Puente custom source para just_audio
│   ├── metronome_stream_source.dart # Source de audio del metrónomo
│   ├── catalog_service.dart       # Catálogo de capítulos y ejercicios
│   ├── settings_service.dart      # Persistencia local (SharedPreferences)
│   └── audio_renderer.dart        # Renderizado de audio
├── screens/
│   ├── menu_screen.dart           # Navegación principal (Ritmo/Instrumento)
│   ├── chapter_screen.dart        # Vista de capítulo
│   ├── mixer_screen.dart          # Consola de mezcla completa
│   ├── metronome_screen.dart      # Metrónomo independiente
│   └── settings_screen.dart       # Configuración de engine/UI
├── widgets/
│   ├── mixer/                     # Componentes granulares de la consola
│   │   ├── channel_strip_container.dart
│   │   ├── track_strip.dart
│   │   ├── track_controls.dart
│   │   ├── master_strip.dart
│   │   ├── master_section.dart
│   │   ├── track_list_section.dart
│   │   └── transport_section.dart
│   ├── waveform/                  # Componentes de visualización
│   │   ├── waveform_painter.dart
│   │   ├── waveform_interaction_controller.dart
│   │   ├── loop_ruler.dart
│   │   └── loop_ruler_painter.dart
│   ├── fader_control.dart
│   ├── knob_control.dart
│   ├── seek_bar.dart
│   ├── studio_header.dart
│   └── waveform_seek_bar.dart
├── utils/
│   ├── audio_analysis_utils.dart
│   ├── mixer_utils.dart
│   ├── wav_header_utils.dart
│   ├── wav_parser.dart
│   └── waveform_utils.dart
└── main.dart                      # Entry point, MultiProvider setup
```

### Motor Nativo (Plugin Flutter)
```
packages/native_audio_engine/
└── lib/
    ├── live_mixer.dart             # Abstracción cross-platform
    ├── live_mixer_native.dart      # Implementación FFI (Android/Windows)
    ├── live_mixer_web.dart         # Implementación WebAssembly + AudioWorklet
    ├── live_mixer_bindings.dart    # Bindings FFI al C++
    ├── soundtouch_bindings.dart    # Bindings FFI a SoundTouch (Time Stretch)
    ├── soundtouch_processor.dart   # Procesador de time stretching
    └── audio_track_info.dart       # Info de pista para el engine
```

---

## 🔧 Pipeline de Audio por Plataforma

| Plataforma | Decodificación | Engine | Salida |
|:---:|:---:|:---:|:---:|
| **Android** | `ffmpeg_kit` → WAV cache → Float32 RAM | C++ LiveMixer (FFI) | Miniaudio |
| **Windows** | Media Foundation (`mfplat`) → Float32 RAM | C++ LiveMixer (FFI) | Miniaudio |
| **Web** | `AudioContext.decodeAudioData` → Float32 | C++ LiveMixer (WASM) | AudioWorklet |

---

## 🛠️ Tech Stack

| Componente | Tecnología |
|:---|:---|
| Framework | Flutter / Dart 3.10+ |
| Motor de Audio | C++ 17 (Miniaudio + SoundTouch) |
| Estado | Provider |
| Audio Player | just_audio (bridge), native_audio_engine (core) |
| Decodificación | ffmpeg_kit (Android), Media Foundation (Windows), Web Audio API (Web) |
| Persistencia | SharedPreferences |
| Compilación Web | Emscripten → WebAssembly |
| Assets | M4A / AAC (compresión extrema sin artefactos de padding) |

---

## 🚀 Getting Started

### Prerequisitos

- **Flutter SDK** ≥ 3.10 (canal stable)
- **C++ Build Tools:**
  - **Windows:** Visual Studio con workload "Desktop development with C++"
  - **Android:** Android NDK + CMake (via Android Studio SDK Manager)
  - **Web:** Emscripten SDK (para compilar el engine WASM)

### Instalación

```bash
# 1. Clonar el repositorio
git clone https://github.com/randazzofederico-coder/Elongacion_Musical.git
cd Elongacion_Musical

# 2. Instalar dependencias
flutter pub get

# 3. Ejecutar la aplicación
flutter run -d windows    # Windows
flutter run -d android    # Android (con dispositivo/emulador conectado)
flutter run -d chrome     # Web (experimental)
```

### Compilar el Engine WebAssembly

```bash
# Desde la raíz del proyecto
./compile.bat             # Windows: compila live_mixer.wasm con Emscripten
```

---

## 📱 Pantallas de la Aplicación

| Pantalla | Descripción |
|:---|:---|
| **Menú Principal** | Navegación por secciones (Ritmo / Instrumento) con acordeones de capítulos y botón de metrónomo |
| **Consola de Mezcla** | Faders, knobs, mute/solo, waveform con zoom, loop ruler, controles de transporte |
| **Metrónomo** | Control de BPM, tap tempo, múltiples patrones con subdivisiones, visualizador de macro ciclo |
| **Configuración** | Ajustes de SoundTouch (Sequence, SeekWindow, Overlap), preferencias de UI |

---

## 🗺️ Roadmap

- [x] Motor C++ nativo con Miniaudio + SoundTouch
- [x] Consola de mezcla multipista con UI profesional
- [x] Metrónomo dinámico con estructuras asimétricas
- [x] Light/Dark mode con persistencia
- [x] Waveform con pinch-to-zoom y loop ruler
- [x] Port a WebAssembly con AudioWorklet
- [x] Corrección FFI IEEE-754 para Android/iOS
- [ ] Capítulos 5-10 con audio real
- [ ] Sección de Ritmo con audio real
- [ ] Refactor de `live_mixer.cpp` en módulos (TrackManager, MetronomeGenerator, StretcherContext)
- [ ] Refactor de `AudioManager.dart` y `MixerStreamSource.dart`
- [ ] Optimización de latencia táctil en Android (~40ms target)
- [ ] Desacoplar engine de audio del thread principal de Flutter (Web Workers)

---

## 📄 Licencia

[Pendiente de definir]

---

<p align="center">
  Desarrollado con 🎶 por <strong>Federico Randazzo</strong>
</p>

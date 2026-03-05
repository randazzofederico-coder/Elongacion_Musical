import os
import subprocess
import sys
from pathlib import Path

# Función para asegurar que tenemos la librería necesaria
def ensure_soundfile():
    try:
        import soundfile
    except ImportError:
        print("⏳ Instalando librería 'soundfile' para procesar audio sin FFmpeg...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "soundfile"])
        print("✅ Librería instalada correctamente.\n")

ensure_soundfile()
import soundfile as sf

INPUT_DIR = r"assets\audio\Con instrumento\Capitulo 1"
OUTPUT_DIR = r"assets\audio\Con instrumento\Capitulo 1 OGG"

def convert_wav_to_ogg():
    input_path = Path(INPUT_DIR)
    if not input_path.exists():
        print(f"Error: No se encontró la carpeta original: {input_path.absolute()}")
        return

    output_path = Path(OUTPUT_DIR)
    output_path.mkdir(parents=True, exist_ok=True)

    wav_files = list(input_path.rglob("*.wav"))
    
    if not wav_files:
        print(f"No se encontraron archivos .wav en {input_path.absolute()}")
        return

    print(f"🎵 Se encontraron {len(wav_files)} archivos .wav.")
    print("Iniciando conversión a OGG (Vorbis)...")
    print("--------------------------------------------------")

    success_count = 0

    for wav_file in wav_files:
        rel_path = wav_file.relative_to(input_path)
        ogg_file = output_path / rel_path.with_suffix('.ogg')
        ogg_file.parent.mkdir(parents=True, exist_ok=True)
        
        print(f"Convirtiendo: {wav_file.name} ... ", end="", flush=True)
        
        try:
            # Leemos el WAV y lo escribimos directamente a OGG Vorbis
            data, samplerate = sf.read(str(wav_file))
            # sf.write usa la librería interna libsndfile que soporta OGG Vorbis de forma nativa
            sf.write(str(ogg_file), data, samplerate, format='OGG', subtype='VORBIS')
            print("¡Listo!")
            success_count += 1
        except Exception as e:
            print(f"❌ Error: {e}")

    print("--------------------------------------------------")
    print(f"✅ Proceso finalizado. Se convirtieron {success_count} de {len(wav_files)} archivos.")
    print(f"📁 Los audios nuevos están listos en: {output_path.absolute()}")

if __name__ == "__main__":
    convert_wav_to_ogg()

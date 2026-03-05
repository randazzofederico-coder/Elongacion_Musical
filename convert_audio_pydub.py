import os
import sys
import subprocess
from pathlib import Path

# Script de conversión usando ffmpeg-python en lugar de pydub para compatibilidad con Python 3.13+
def ensure_libs():
    try:
        import ffmpeg
    except ImportError:
        print("⏳ Instalando librería 'ffmpeg-python'...")
        subprocess.check_call([sys.executable, "-m", "pip", "install", "ffmpeg-python"])
        print("✅ Librería instalada correctamente.\n")

ensure_libs()
import ffmpeg

DIRS_TO_CONVERT = [
    (r"assets\audio\Con instrumento\Capitulo 1", r"assets\audio\Con instrumento\Capitulo 1 M4A"),
    (r"assets\audio\Con instrumento\Capitulo 2", r"assets\audio\Con instrumento\Capitulo 2 M4A"),
    (r"assets\audio\Con instrumento\Capitulo 3", r"assets\audio\Con instrumento\Capitulo 3 M4A"),
]

def convert_wav_to_m4a():
    for input_dir, output_dir in DIRS_TO_CONVERT:
        input_path = Path(input_dir)
        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)

        wav_files = list(input_path.rglob("*.wav"))
        
        if not wav_files:
            print(f"No se encontraron archivos .wav en {input_dir}.")
            continue

        print(f"🎵 Se encontraron {len(wav_files)} archivos .wav en {input_dir}.")
        print(f"Iniciando conversión a M4A (AAC)...")
        print("--------------------------------------------------")

        success_count = 0

        for wav_file in wav_files:
            rel_path = wav_file.relative_to(input_path)
            m4a_file = output_path / rel_path.with_suffix('.m4a')
            m4a_file.parent.mkdir(parents=True, exist_ok=True)
            
            print(f"Convirtiendo: {wav_file.name} ... ", end="", flush=True)
            
            try:
                (
                    ffmpeg
                    .input(str(wav_file))
                    .output(str(m4a_file), format='ipod', acodec='aac')
                    .overwrite_output()
                    .run(quiet=True)
                )
                print("¡Listo!")
                success_count += 1
            except ffmpeg.Error as e:
                print(f"❌ Error de FFmpeg: {e.stderr.decode('utf8') if e.stderr else e}")
                break
            except Exception as e:
                print(f"❌ Error: {e}")
                break

        print("--------------------------------------------------")
        print(f"✅ Proceso finalizado para {input_dir}. Se convirtieron {success_count} de {len(wav_files)} archivos.\n")

if __name__ == "__main__":
    convert_wav_to_m4a()

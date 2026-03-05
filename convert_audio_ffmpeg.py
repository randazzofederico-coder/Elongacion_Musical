import os
import subprocess
from pathlib import Path

INPUT_DIR = r"assets\audio\Con instrumento\Capitulo 1"
OUTPUT_DIR = r"assets\audio\Con instrumento\Capitulo 1 MP3"

def convert_wav_to_mp3():
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

    print(f"🎵 Se encontraron {len(wav_files)} archivos .wav. Iniciando conversión a MP3 con FFmpeg...")
    print("--------------------------------------------------")

    success_count = 0

    for wav_file in wav_files:
        rel_path = wav_file.relative_to(input_path)
        mp3_file = output_path / rel_path.with_suffix('.mp3')
        mp3_file.parent.mkdir(parents=True, exist_ok=True)
        
        # -c:a libmp3lame: Códec de audio MP3
        # -q:a 2: Nivel de calidad VBR 2 (aprox. 190 kbps)
        cmd = [
            "ffmpeg", 
            "-y", 
            "-i", str(wav_file), 
            "-c:a", "libmp3lame", 
            "-q:a", "2", 
            str(mp3_file)
        ]
        
        print(f"Convirtiendo: {wav_file.name} ... ", end="", flush=True)
        
        try:
            # Quitamos el capture_output=True temporalmente para ver EXACTAMENTE
            # si FFmpeg se queda esperando input, si tira error o qué hace.
            # stdout=subprocess.PIPE y stderr=subprocess.PIPE pueden bloquear 
            # si el buffer se llena. Redirigimos al null para que no moleste visualmente
            # pero no bloquee.
            result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            
            if result.returncode == 0:
                print("¡Listo!")
                success_count += 1
            else:
                print(f"ERROR (Code: {result.returncode})")
                
        except Exception as e:
            print(f"\n❌ Excepción al correr ffmpeg: {e}")
            return

    print("--------------------------------------------------")
    print(f"✅ Proceso finalizado. Se convirtieron {success_count} de {len(wav_files)} archivos.")

if __name__ == "__main__":
    convert_wav_to_mp3()

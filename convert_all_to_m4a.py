import os
import subprocess
from pathlib import Path

BASE_DIR = Path(r"assets\audio\Con instrumento")

def convert_wav_to_m4a():
    if not BASE_DIR.exists():
        print(f"Error: No se encontró la carpeta base: {BASE_DIR.absolute()}")
        return

    # Find all chapters folders that don't end in M4A
    chapter_dirs = [d for d in BASE_DIR.iterdir() if d.is_dir() and not d.name.endswith("M4A") and d.name.startswith("Capitulo")]
    
    if not chapter_dirs:
        print("No se encontraron carpetas de capítulos.")
        return

    total_converted = 0
    total_found = 0

    for chapter_dir in chapter_dirs:
        wav_files = list(chapter_dir.rglob("*.wav"))
        if not wav_files:
            continue
            
        total_found += len(wav_files)
        
        # Calculate output directory for this chapter
        output_dir_name = f"{chapter_dir.name} M4A"
        output_dir = chapter_dir.parent / output_dir_name
        output_dir.mkdir(parents=True, exist_ok=True)
        
        print(f"🎵 Procesando {chapter_dir.name}: {len(wav_files)} archivos .wav")
        print("--------------------------------------------------")

        for wav_file in wav_files:
            rel_path = wav_file.relative_to(chapter_dir)
            m4a_file = output_dir / rel_path.with_suffix('.m4a')
            m4a_file.parent.mkdir(parents=True, exist_ok=True)
            
            # Skip if already exists
            if m4a_file.exists():
                print(f"Saltando (ya existe): {m4a_file.name}")
                continue
            
            # -c:a aac: Códec de audio AAC (M4A)
            # -b:a 192k: Bitrate 192k
            cmd = [
                "ffmpeg", 
                "-y", 
                "-i", str(wav_file), 
                "-c:a", "aac", 
                "-b:a", "192k", 
                str(m4a_file)
            ]
            
            print(f"Convirtiendo: {wav_file.name} ... ", end="", flush=True)
            
            try:
                result = subprocess.run(cmd, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                
                if result.returncode == 0:
                    print("¡Listo!")
                    total_converted += 1
                else:
                    print(f"ERROR (Code: {result.returncode})")
                    
            except Exception as e:
                print(f"\n❌ Excepción al correr ffmpeg: {e}")
                return

    print("--------------------------------------------------")
    print(f"✅ Proceso finalizado. Se convirtieron {total_converted} archivos nuevos de {total_found} totales.")

if __name__ == "__main__":
    convert_wav_to_m4a()

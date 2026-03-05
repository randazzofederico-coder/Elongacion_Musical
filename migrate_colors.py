import os
import re

lib_dir = r"c:\dev\Elongacion_Musical\lib"

def process_file(filepath):
    if "app_colors.dart" in filepath.replace("\\", "/"):
        return
    
    with open(filepath, 'r', encoding='utf-8') as f:
        content = f.read()

    # Match AppColors.property and append (context) if not present
    new_content = re.sub(r'AppColors\.([a-z][a-zA-Z0-9_]*)(?!\()', r'AppColors.\1(context)', content)

    if new_content != content:
        with open(filepath, 'w', encoding='utf-8') as f:
            f.write(new_content)
        print(f"Updated {filepath}")

for root, dirs, files in os.walk(lib_dir):
    for file in files:
        if file.endswith(".dart"):
            process_file(os.path.join(root, file))

#!/usr/bin/env python3
"""Package tracked plugin files; personal runtime data is never collected."""
from pathlib import Path
import hashlib
import subprocess
import zipfile

ROOT = Path(__file__).resolve().parents[1]
OUTPUT = ROOT / 'dist/miuread-v5.9.0-voyage-source.zip'


def main():
    files = subprocess.check_output(['git', 'ls-files', '-z', '--', 'miuread.koplugin/'], cwd=ROOT).decode().split('\0')
    files = sorted(name for name in files if name)
    forbidden = {'.epub', '.log', '.db', '.sqlite', '.md', '.zip'}
    for name in files:
        path = Path(name)
        if path.suffix.lower() in forbidden or path.name in {'.DS_Store', 'miuread.lua', 'settings.reader.lua'}:
            raise SystemExit('Refusing runtime or unsupported package file: ' + name)
    required = ['miuread.koplugin/miuread/' + name for name in ['auth.lua', 'on_demand_thoughts.lua', 'on_demand_popup.lua', 'thought_display_text.lua']]
    if not all(name in files for name in required):
        raise SystemExit('Stage or commit the fork files before building the package.')
    OUTPUT.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(OUTPUT, 'w', zipfile.ZIP_DEFLATED) as archive:
        for name in files:
            archive.write(ROOT / name, name)
    digest = hashlib.sha256(OUTPUT.read_bytes()).hexdigest()
    OUTPUT.with_suffix('.zip.sha256').write_text(digest + '  ' + OUTPUT.name + '\n')
    print(OUTPUT)
    print('SHA-256:', digest)


if __name__ == '__main__':
    main()

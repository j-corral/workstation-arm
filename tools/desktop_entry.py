#!/usr/bin/env python3
"""Create only workstation-owned launchers; quote desktop Exec paths correctly."""
import os
from pathlib import Path
import sys

name, title, binary = sys.argv[1:]
# freedesktop Exec quoting has a second layer after string escape processing.
escaped = binary.replace('\\', '\\\\').replace('"', '\\"').replace('`', '\\`').replace('$', '\\$').replace('%', '%%')
escaped = escaped.replace('\\', '\\\\')
root = Path.home() / '.local/share/applications'
root.mkdir(parents=True, exist_ok=True)
path = root / f'workstation-{name}.desktop'
if path.is_symlink():
    raise SystemExit('Refusing symlink desktop entry')
path.write_text(f'[Desktop Entry]\nType=Application\nName={title}\nExec="{escaped}" %U\nTerminal=false\nCategories=Development;\n')
os.chmod(path, 0o644)

#!/usr/bin/env python3
"""Remove unsafe GTK global-menu modules while preserving user GTK settings."""
import os
from pathlib import Path
import stat
import sys
import tempfile


UNSAFE_MODULES = {'appmenu-gtk-module', 'appmenu-gtk3-module'}


def update(path):
    path = Path(path)
    if path.is_symlink():
        raise ValueError(f'Refusing symlink configuration: {path}')
    old = path.read_text() if path.exists() else ''
    lines = []
    changed = False
    for line in old.splitlines(keepends=True):
        if not line.startswith('gtk-modules='):
            lines.append(line)
            continue
        modules = [module for module in line.rstrip('\n').split('=', 1)[1].split(':') if module]
        retained = [module for module in modules if module not in UNSAFE_MODULES]
        if retained == modules:
            lines.append(line)
        elif retained:
            lines.append(f"gtk-modules={':'.join(retained)}\n")
            changed = True
        else:
            changed = True
    new = ''.join(lines)
    if not changed:
        return
    previous = path.stat()
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix='.workstation-gtk-')
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(new)
            os.fchown(stream.fileno(), previous.st_uid, previous.st_gid)
            os.fchmod(stream.fileno(), stat.S_IMODE(previous.st_mode))
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    update(sys.argv[1])

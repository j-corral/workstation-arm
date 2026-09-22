#!/usr/bin/env python3
"""Set the system French PC layout without replacing unrelated keyboard settings."""
import os
from pathlib import Path
import re
import stat
import sys
import tempfile


def update(path):
    path = Path(path)
    if path.is_symlink():
        raise ValueError(f'Refusing symlink configuration: {path}')
    old = path.read_text() if path.exists() else ''
    values = {'XKBMODEL': 'pc105', 'XKBLAYOUT': 'fr', 'XKBVARIANT': ''}
    lines = []
    seen = set()
    for line in old.splitlines(keepends=True):
        match = re.match(r'^\s*(?:export\s+)?(XKBMODEL|XKBLAYOUT|XKBVARIANT)\s*=', line)
        if match:
            key = match.group(1)
            if key not in seen:
                lines.append(f'{key}="{values[key]}"\n')
                seen.add(key)
        else:
            lines.append(line)
    new = ''.join(lines)
    for key, value in values.items():
        if key not in seen:
            if new and not new.endswith('\n'):
                new += '\n'
            new += f'{key}="{value}"\n'
    if new == old:
        return
    previous = path.stat() if path.exists() else None
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix='.workstation-keyboard-')
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(new)
            if previous:
                os.fchown(stream.fileno(), previous.st_uid, previous.st_gid)
            os.fchmod(stream.fileno(), stat.S_IMODE(previous.st_mode) if previous else 0o644)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    update(sys.argv[1])

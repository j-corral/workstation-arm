#!/usr/bin/env python3
"""Atomic, idempotent managed sections; preserve other content and file mode."""
import os
from pathlib import Path
import stat
import sys
import tempfile


def update(path, name, content):
    path = Path(path)
    if path.is_symlink():
        raise ValueError(f'Refusing symlink configuration: {path}')
    start, end = f'# >>> workstation:{name} >>>', f'# <<< workstation:{name} <<<'
    old = path.read_text() if path.exists() else ''
    lines = old.splitlines(keepends=True)
    starts = [i for i, s in enumerate(lines) if s.rstrip('\r\n') == start]
    ends = [i for i, s in enumerate(lines) if s.rstrip('\r\n') == end]
    block = start + '\n' + content.rstrip('\n') + '\n' + end + '\n'
    if not starts and not ends:
        new = old + ('\n' if old and not old.endswith('\n') else '') + block
    elif len(starts) == len(ends) == 1 and starts[0] < ends[0]:
        new = ''.join(lines[:starts[0]]) + block + ''.join(lines[ends[0] + 1:])
    else:
        raise ValueError(f'Malformed or duplicate managed markers in {path}; no changes made')
    if new == old:
        return
    mode = stat.S_IMODE(path.stat().st_mode) if path.exists() else 0o600
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix='.workstation-')
    try:
        with os.fdopen(fd, 'w') as stream:
            stream.write(new)
            os.fchmod(stream.fileno(), mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    update(sys.argv[1], sys.argv[2], Path(sys.argv[3]).read_text())

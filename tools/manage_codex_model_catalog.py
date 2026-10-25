#!/usr/bin/env python3
"""Safely maintain the top-level Codex model catalog setting."""
import json
import os
from pathlib import Path
import re
import stat
import sys
import tempfile


START = '# >>> workstation:codex-model-catalog >>>'
END = '# <<< workstation:codex-model-catalog <<<'
KEY = re.compile(r'^model_catalog_json\s*=', re.MULTILINE)
TABLE = re.compile(r'^\s*\[', re.MULTILINE)


def replace(path: Path, catalog: Path) -> None:
    if path.is_symlink() or catalog.is_symlink():
        raise ValueError('Refusing symlink Codex model catalog path')
    source = path.read_text()
    lines = source.splitlines(keepends=True)
    starts = [index for index, line in enumerate(lines) if line.rstrip('\r\n') == START]
    ends = [index for index, line in enumerate(lines) if line.rstrip('\r\n') == END]
    block = f'{START}\nmodel_catalog_json = {json.dumps(str(catalog))}\n{END}\n'

    if len(starts) == len(ends) == 1 and starts[0] < ends[0]:
        updated = ''.join(lines[:starts[0]]) + block + ''.join(lines[ends[0] + 1:])
    elif not starts and not ends:
        if KEY.search(source):
            raise ValueError('Existing model_catalog_json is not workstation-managed; refusing to replace it')
        table = TABLE.search(source)
        insertion = table.start() if table else len(source)
        updated = source[:insertion] + block + source[insertion:]
    else:
        raise ValueError('Malformed or duplicate workstation model catalog markers; no changes made')

    if updated == source:
        return
    mode = stat.S_IMODE(path.stat().st_mode)
    descriptor, temporary = tempfile.mkstemp(dir=path.parent, prefix='.workstation-')
    try:
        with os.fdopen(descriptor, 'w') as output:
            output.write(updated)
            os.fchmod(output.fileno(), mode)
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


if __name__ == '__main__':
    replace(Path(sys.argv[1]), Path(sys.argv[2]))

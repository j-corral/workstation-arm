#!/usr/bin/env python3
"""Read immutable artifact metadata and reject wrong-architecture executables."""
import json
from pathlib import Path
import struct
import sys
import tarfile
import zipfile


def main():
    action, *args = sys.argv[1:]
    if action == 'lookup':
        item = json.loads(Path(args[0]).read_text())[args[1]]
        print(item['url'], item.get('algorithm', 'sha256'), item['digest'], sep='\t')
    elif action == 'elf':
        with open(args[0], 'rb') as stream:
            header = stream.read(20)
        if len(header) != 20 or header[:6] != b'\x7fELF\x02\x01' or struct.unpack('<H', header[18:20])[0] != 183:
            raise SystemExit(f'Not a little-endian Linux ARM64 ELF: {args[0]}')
    elif action == 'extract':
        archive, target = args
        root = Path(target)
        root.mkdir(mode=0o700)
        if zipfile.is_zipfile(archive):
            with zipfile.ZipFile(archive) as z:
                for item in z.infolist():
                    p = Path(item.filename)
                    if p.is_absolute() or '..' in p.parts or ((item.external_attr >> 16) & 0o170000) == 0o120000:
                        raise SystemExit('Unsafe ZIP member')
                z.extractall(root)
        else:
            # Ubuntu 26.04 Python supports the standard safe data filter.
            with tarfile.open(archive) as t:
                t.extractall(root, filter='data')
    else:
        raise SystemExit('Unknown artifact operation')


if __name__ == '__main__':
    main()

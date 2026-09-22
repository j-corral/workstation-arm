#!/usr/bin/env python3
"""Install audited static theme assets; never execute upstream installers."""
from pathlib import Path
import shutil
import sys


def copy(source, target):
    source, target = Path(source), Path(target)
    # Refuse links both in the payload and existing destination, including parents.
    for path in [source, *source.rglob('*')] if source.is_dir() else [source]:
        if path.is_symlink():
            raise ValueError(f'Symlink theme asset: {path}')
    for path in [target, *target.parents, *(target.rglob('*') if target.is_dir() else [])]:
        if path.is_symlink():
            raise ValueError(f'Symlink theme destination: {path}')
    target.parent.mkdir(parents=True, exist_ok=True)
    if source.is_dir():
        shutil.copytree(source, target, dirs_exist_ok=True)
    else:
        shutil.copy2(source, target)


def prepare(source, share, greeter):
    source, share, greeter = map(Path, (source, share, greeter))
    name = 'MacTahoe-Light'
    copy(source / 'plasma/desktoptheme' / name, share / 'plasma/desktoptheme' / name)
    copy(source / 'plasma/desktoptheme/icons', share / 'plasma/desktoptheme' / name / 'icons')
    copy(source / 'color-schemes/MacTahoeLight.colors', share / 'color-schemes/MacTahoeLight.colors')
    decoration = share / 'aurorae/themes' / name
    copy(source / 'aurorae' / name, decoration)
    copy(source / 'aurorae/icons-Light', decoration)
    copy(source / 'aurorae/Lightrc', decoration / (name + 'rc'))
    for filename in ('metadata.json', 'metadata.desktop'):
        copy(source / 'aurorae' / filename, decoration / filename)
        path = decoration / filename
        path.write_text(path.read_text().replace('theme_name', name))
    copy(source / 'sddm/MacTahoe-6.0', greeter)
    copy(source / 'sddm/images/Background-Light.jpeg', greeter / 'Background.jpeg')
    copy(source / 'sddm/images/Preview-Light.jpeg', greeter / 'Preview.jpeg')
    # Keep the upstream name: Main.qml uses absolute /usr/share/sddm/themes/MacTahoe paths.
    copy(source / 'LICENSE', greeter / 'LICENSE')
    for path in [greeter, *greeter.rglob('*')]:
        path.chmod(0o755 if path.is_dir() else 0o644)


if __name__ == '__main__':
    if sys.argv[1] == 'prepare':
        prepare(*sys.argv[2:])
    elif sys.argv[1] == 'copy':
        copy(*sys.argv[2:])
    else:
        raise SystemExit('Unknown operation')

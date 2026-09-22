#!/usr/bin/env python3
"""Install audited static theme assets; never execute upstream installers."""
from pathlib import Path
import os
import shutil
import sys
import tempfile


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


def prepare(source, share, greeter, config):
    source, share, greeter, config = map(Path, (source, share, greeter, config))
    name = 'MacTahoe-Light'
    copy(source / 'plasma/desktoptheme' / name, share / 'plasma/desktoptheme' / name)
    copy(source / 'plasma/desktoptheme/icons', share / 'plasma/desktoptheme' / name / 'icons')
    copy(source / 'color-schemes/MacTahoeLight.colors', share / 'color-schemes/MacTahoeLight.colors')
    copy(source / 'plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Light',
         share / 'plasma/look-and-feel/com.github.vinceliuice.MacTahoe-Light')
    for layout in ('org.github.desktop.MacOSDock', 'org.github.desktop.MacOSPanel'):
        copy(source / 'plasma/layout-templates' / layout, share / 'plasma/layout-templates' / layout)
    for wallpaper in ('MacTahoe', 'MacTahoe-Light'):
        copy(source / 'wallpapers' / wallpaper, share / 'wallpapers' / wallpaper)
    copy(source / 'Kvantum/MacTahoe', config / 'Kvantum/MacTahoe')
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


def install_icons(source, destination):
    source, destination = Path(source), Path(destination)
    destination.mkdir(parents=True, exist_ok=True)
    for name in ('MacTahoe', 'MacTahoe-light', 'MacTahoe-dark'):
        origin = source / name
        target = destination / name
        if not origin.is_dir() or origin.is_symlink() or target.is_symlink():
            raise ValueError(f'Unsafe icon theme directory: {name}')
        for path in origin.rglob('*'):
            if path.is_symlink():
                # Upstream icons contain many relative links; ensure they stay
                # inside one of the three selected theme directories.
                resolved = Path(os.path.abspath(os.path.join(path.parent, os.readlink(path))))
                if not resolved.is_relative_to(source.resolve()):
                    raise ValueError(f'Icon link escapes theme root: {path}')
        staged = Path(tempfile.mkdtemp(dir=destination, prefix='.workstation-icons-'))
        old = None
        try:
            shutil.copytree(origin, staged / name, symlinks=True)
            if target.exists():
                old = Path(tempfile.mkdtemp(dir=destination, prefix='.workstation-icons-old-'))
                os.replace(target, old / name)
            os.replace(staged / name, target)
        except BaseException:
            if old is not None and not target.exists():
                os.replace(old / name, target)
            raise
        finally:
            shutil.rmtree(staged)
            if old is not None:
                shutil.rmtree(old)


if __name__ == '__main__':
    if sys.argv[1] == 'prepare':
        prepare(*sys.argv[2:])
    elif sys.argv[1] == 'copy':
        copy(*sys.argv[2:])
    elif sys.argv[1] == 'icons':
        install_icons(*sys.argv[2:])
    else:
        raise SystemExit('Unknown operation')

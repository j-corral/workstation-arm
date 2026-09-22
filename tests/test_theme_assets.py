"""Theme copying must preserve unrelated assets and refuse symlink writes."""
import importlib.util
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('theme_assets', ROOT / 'tools/theme_assets.py')
theme = importlib.util.module_from_spec(spec)
spec.loader.exec_module(theme)


class ThemeAssetsTests(unittest.TestCase):
    def test_icon_install_preserves_internal_links_and_other_theme(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            staged = root / 'staged'
            installed = root / 'installed'
            for name in ('MacTahoe', 'MacTahoe-light', 'MacTahoe-dark'):
                (staged / name).mkdir(parents=True)
                (staged / name / 'index.theme').write_text(name)
            (staged / 'MacTahoe' / 'base.svg').write_text('icon')
            (staged / 'MacTahoe-light' / 'base.svg').symlink_to('../MacTahoe/base.svg')
            (installed / 'breeze').mkdir(parents=True)
            (installed / 'breeze' / 'index.theme').write_text('fallback')
            theme.install_icons(staged, installed)
            theme.install_icons(staged, installed)
            self.assertEqual((installed / 'MacTahoe-light/base.svg').read_text(), 'icon')
            self.assertEqual((installed / 'breeze/index.theme').read_text(), 'fallback')

    def test_icon_install_rejects_escape(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            staged = root / 'staged'
            installed = root / 'installed'
            for name in ('MacTahoe', 'MacTahoe-light', 'MacTahoe-dark'):
                (staged / name).mkdir(parents=True)
            (staged / 'MacTahoe/base.svg').symlink_to('../../../outside')
            with self.assertRaises(ValueError):
                theme.install_icons(staged, installed)

    def test_copy_is_repeatable_and_preserves_other_themes(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            source = root / 'source'
            source.mkdir()
            (source / 'Main.qml').write_text('theme content')
            destination = root / 'themes/MacTahoe'
            breeze = root / 'themes/breeze'
            breeze.mkdir(parents=True)
            (breeze / 'Main.qml').write_text('fallback')
            theme.copy(source, destination)
            theme.copy(source, destination)
            self.assertEqual((destination / 'Main.qml').read_text(), 'theme content')
            self.assertEqual((breeze / 'Main.qml').read_text(), 'fallback')

    def test_refuses_payload_and_destination_links(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory).resolve()
            source = root / 'source'
            source.mkdir()
            victim = root / 'victim'
            victim.write_text('unchanged')
            (source / 'Main.qml').symlink_to(victim)
            with self.assertRaises(ValueError):
                theme.copy(source, root / 'destination')
            (source / 'Main.qml').unlink()
            (source / 'Main.qml').write_text('theme')
            destination = root / 'destination'
            destination.mkdir()
            (destination / 'Main.qml').symlink_to(victim)
            with self.assertRaises(ValueError):
                theme.copy(source, destination)
            self.assertEqual(victim.read_text(), 'unchanged')

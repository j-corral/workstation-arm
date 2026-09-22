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

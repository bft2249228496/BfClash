import contextlib
import hashlib
import importlib.util
import io
from pathlib import Path
import sys
import tempfile
import unittest
from unittest import mock

MODULE_PATH = Path(__file__).resolve().parents[1] / 'prepare_sqlite_assets.py'
spec = importlib.util.spec_from_file_location('prepare_sqlite_assets', MODULE_PATH)
module = importlib.util.module_from_spec(spec)
spec.loader.exec_module(module)


class PrepareAssetsTest(unittest.TestCase):
    def run_prepare(self, valid):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            manifest = root / 'package/lib/src/hook/asset_hashes.dart'
            manifest.parent.mkdir(parents=True)
            payload = b'verified test asset'
            digest = hashlib.sha256(payload).hexdigest()
            filename = 'libsqlite3.arm64.android.so'
            manifest.write_text("const String? releaseTag = 'sqlite3-test';\n" + f"'{filename}': '{digest}',\n")
            cache = root / 'cache'

            def download(command, **kwargs):
                directory = Path(command[command.index('--dir') + 1])
                (directory / filename).write_bytes(payload if valid else b'wrong bytes')
                return subprocess_result

            subprocess_result = mock.Mock(returncode=0)
            argv = ['prepare', '--package', str(root / 'package'), '--cache', str(cache)]
            with mock.patch.object(module, 'ASSETS', (filename,)), \
                 mock.patch.object(module.subprocess, 'run', side_effect=download) as run, \
                 mock.patch.object(module.time, 'sleep'), \
                 mock.patch.object(sys, 'argv', argv), contextlib.redirect_stdout(io.StringIO()):
                if valid:
                    module.main()
                    self.assertEqual((cache / f'download-{digest[:8]}' / 'libsqlite3.so').read_bytes(), payload)
                else:
                    with self.assertRaises(SystemExit):
                        module.main()
                    self.assertEqual(run.call_count, 3)
                    self.assertFalse(cache.exists())

    def test_verified_asset_is_cached(self):
        self.run_prepare(True)

    def test_hash_mismatch_never_enters_cache(self):
        self.run_prepare(False)


if __name__ == '__main__':
    unittest.main()

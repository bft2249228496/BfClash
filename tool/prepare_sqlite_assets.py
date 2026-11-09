#!/usr/bin/env python3
"""Prime the sqlite3 build-hook cache with hash-verified official assets."""
import argparse
import hashlib
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import time

ASSETS = (
    'libsqlite3.arm.android.so',
    'libsqlite3.arm64.android.so',
    'libsqlite3.x64.android.so',
    'libsqlite3.x64.linux.so',
)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--package', required=True, type=Path)
    parser.add_argument('--cache', required=True, type=Path)
    args = parser.parse_args()
    manifest = (args.package / 'lib/src/hook/asset_hashes.dart').read_text()
    tag = re.search(r"const String\? releaseTag = '([^']+)';", manifest)
    if not tag:
        raise SystemExit('sqlite3 release tag is missing')
    with tempfile.TemporaryDirectory(prefix='bfclash-sqlite-') as tmp:
        for name in ASSETS:
            expected = re.search(r"'" + re.escape(name) + r"': '([0-9a-f]{64})'", manifest)
            if not expected:
                raise SystemExit(f'No pinned hash for {name}')
            digest = expected.group(1)
            asset = Path(tmp) / name
            for attempt in range(1, 4):
                result = subprocess.run([
                    'gh', 'release', 'download', tag.group(1),
                    '--repo', 'simolus3/sqlite3.dart', '--pattern', name,
                    '--dir', tmp, '--clobber',
                ], check=False)
                if result.returncode == 0 and asset.is_file() and hashlib.sha256(asset.read_bytes()).hexdigest() == digest:
                    break
                asset.unlink(missing_ok=True)
                if attempt == 3:
                    raise SystemExit(f'Could not obtain verified SQLite asset: {name}')
                time.sleep(attempt)
            destination = args.cache / f'download-{digest[:8]}' / 'libsqlite3.so'
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(asset, destination)
            print(f'Verified {name}')


if __name__ == '__main__':
    main()

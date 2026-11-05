import os
import pathlib
import subprocess
import tempfile
import unittest


SCRIPT = pathlib.Path(__file__).with_name('bfclash_sync_upstream.sh')


def git(directory, *args):
    return subprocess.run(
        ['git', '-C', str(directory), *args],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True,
    ).stdout.strip()


class UpstreamMergeTest(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = pathlib.Path(self.temp.name)
        self.upstream = root / 'upstream'
        self.upstream.mkdir()
        git(self.upstream, 'init', '-b', 'FlClash')
        git(self.upstream, 'config', 'user.name', 'test')
        git(self.upstream, 'config', 'user.email', 'test@example.invalid')
        (self.upstream / 'shared.txt').write_text('base\n')
        git(self.upstream, 'add', '.')
        git(self.upstream, 'commit', '-m', 'base')
        self.integration = root / 'integration'
        subprocess.run(['git', 'clone', str(self.upstream), str(self.integration)],
                       check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        git(self.integration, 'config', 'user.name', 'test')
        git(self.integration, 'config', 'user.email', 'test@example.invalid')
        (self.integration / 'feature.txt').write_text('tailscale\n')
        git(self.integration, 'add', '.')
        git(self.integration, 'commit', '-m', 'feature')
        self.output = root / 'output'

    def run_sync(self):
        environment = os.environ.copy()
        environment.update(BFCLASH_UPSTREAM_URL=str(self.upstream),
                           BFCLASH_UPSTREAM_REF='FlClash',
                           GITHUB_OUTPUT=str(self.output))
        return subprocess.run(['bash', str(SCRIPT)], cwd=self.integration,
                              env=environment, capture_output=True, text=True)

    def test_no_update_and_successful_merge_preserve_feature(self):
        result = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('updated=false', self.output.read_text())
        (self.upstream / 'new.txt').write_text('upstream\n')
        git(self.upstream, 'add', '.')
        git(self.upstream, 'commit', '-m', 'upstream')
        result = self.run_sync()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn('updated=true', self.output.read_text())
        self.assertEqual((self.integration / 'feature.txt').read_text(), 'tailscale\n')
        self.assertEqual((self.integration / 'new.txt').read_text(), 'upstream\n')

    def test_conflict_stops_before_recording_success(self):
        (self.integration / 'shared.txt').write_text('integration\n')
        git(self.integration, 'add', '.')
        git(self.integration, 'commit', '-m', 'integration')
        before = git(self.integration, 'rev-parse', 'HEAD')
        (self.upstream / 'shared.txt').write_text('upstream\n')
        git(self.upstream, 'add', '.')
        git(self.upstream, 'commit', '-m', 'upstream')
        result = self.run_sync()
        self.assertNotEqual(result.returncode, 0)
        self.assertEqual(git(self.integration, 'rev-parse', 'HEAD'), before)
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()

import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import dotctl


class SkipReasonTest(unittest.TestCase):
    def test_platform_mismatch(self):
        self.assertEqual(
            dotctl.skip_reason("rofi", "darwin", "work", "linux", "", ""),
            "platform: linux",
        )

    def test_platform_list_match(self):
        self.assertIsNone(
            dotctl.skip_reason("x", "darwin", "work", "linux darwin", "", "")
        )

    def test_profile_mismatch(self):
        self.assertEqual(
            dotctl.skip_reason("claude", "darwin", "personal", "", "work", ""),
            "profile: work",
        )

    def test_skip_wins(self):
        self.assertEqual(
            dotctl.skip_reason("rofi", "linux", "personal", "linux", "", "rofi"),
            "config: SKIP",
        )


class ClassifyTest(unittest.TestCase):
    def test_missing(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d) / "home"
            home.mkdir()
            source = Path(d) / "src" / "foo"
            source.parent.mkdir()
            source.write_text("x")
            self.assertEqual(
                dotctl.classify(home / ".config" / "foo", source, home),
                "missing",
            )

    def test_real_file(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d) / "home"
            home.mkdir()
            target = home / ".gitconfig"
            target.write_text("x")
            source = Path(d) / "src" / "gitconfig"
            source.parent.mkdir()
            source.write_text("x")
            self.assertEqual(dotctl.classify(target, source, home), "real-file")

    def test_symlink_ok(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d) / "home"
            home.mkdir()
            source = Path(d) / "src" / "config"
            source.parent.mkdir()
            source.write_text("x")
            target = home / ".config" / "config"
            target.parent.mkdir()
            target.symlink_to(source)
            self.assertEqual(dotctl.classify(target, source, home), "ok")

    def test_wrong_target(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d) / "home"
            home.mkdir()
            source = Path(d) / "src" / "config"
            source.parent.mkdir()
            source.write_text("x")
            other = Path(d) / "other"
            other.write_text("x")
            target = home / ".config" / "config"
            target.parent.mkdir()
            target.symlink_to(other)
            self.assertEqual(dotctl.classify(target, source, home), "wrong-target")

    def test_parent_symlink(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d) / "home"
            home.mkdir()
            real = Path(d) / "src" / "nvim"
            real.mkdir(parents=True)
            (real / "init.lua").write_text("x")
            (home / ".config").mkdir()
            (home / ".config" / "nvim").symlink_to(real)
            source = real / "init.lua"
            target = home / ".config" / "nvim" / "init.lua"
            self.assertEqual(dotctl.classify(target, source, home), "wrong-target")

    def test_dangling(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d) / "home"
            home.mkdir()
            source = Path(d) / "src" / "config"
            source.parent.mkdir()
            source.write_text("x")
            target = home / ".config" / "config"
            target.parent.mkdir()
            target.symlink_to(Path(d) / "missing")
            self.assertEqual(dotctl.classify(target, source, home), "dangling")


class DeployEntriesTest(unittest.TestCase):
    def test_deploy_set(self):
        with tempfile.TemporaryDirectory() as d:
            root = Path(d)
            (root / ".config").mkdir()
            (root / ".config" / "foo").write_text("x")
            (root / "Makefile").write_text("x")
            (root / "README.md").write_text("x")
            (root / "AGENTS.md").write_text("x")
            (root / ".gitignore").write_text("ignored\n")
            (root / "ignored").write_text("x")
            (root / "nested").mkdir()
            (root / "nested" / "AGENTS.md").write_text("x")
            subprocess.run(["git", "init", "-q"], cwd=root, check=True)
            subprocess.run(["git", "add", "-A"], cwd=root, check=True)
            (root / "new.conf").write_text("x")
            self.assertEqual(
                dotctl.deploy_entries(root),
                [".config/foo", "nested/AGENTS.md", "new.conf"],
            )


if __name__ == "__main__":
    unittest.main()

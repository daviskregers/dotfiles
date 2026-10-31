import contextlib
import io
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

import dotctl


def make_module(root: Path, files: dict[str, str]) -> None:
    for rel, content in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)
    subprocess.run(["git", "init", "-q"], cwd=root, check=True)
    subprocess.run(["git", "add", "-A"], cwd=root, check=True)


def write_tree(root: Path, files: dict[str, str]) -> None:
    for rel, content in files.items():
        path = root / rel
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_text(content)


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


class InstallTest(unittest.TestCase):
    def test_install_links_missing(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "git"
            make_module(module, {".gitconfig": "x"})
            home = Path(d) / "home"
            home.mkdir()
            rc = dotctl.install("git", module, home, "linux", "personal", "", "", "")
            self.assertEqual(rc, 0)
            target = home / ".gitconfig"
            self.assertTrue(target.is_symlink())
            self.assertEqual(target.resolve(), (module / ".gitconfig").resolve())

    def test_install_is_idempotent(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "git"
            make_module(module, {".gitconfig": "x"})
            home = Path(d) / "home"
            home.mkdir()
            dotctl.install("git", module, home, "linux", "personal", "", "", "")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.install(
                    "git", module, home, "linux", "personal", "", "", ""
                )
            self.assertEqual(rc, 0)
            self.assertIn("git: ok (1)", output.getvalue())

    def test_install_refuses_real_file(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "git"
            make_module(module, {".gitconfig": "x"})
            home = Path(d) / "home"
            home.mkdir()
            target = home / ".gitconfig"
            target.write_text("real")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.install(
                    "git", module, home, "linux", "personal", "", "", ""
                )
            self.assertEqual(rc, 1)
            self.assertEqual(target.read_text(), "real")
            self.assertIn("conflict", output.getvalue())

    def test_install_skips_inactive(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "claude"
            make_module(module, {".claude/settings.json": "x"})
            home = Path(d) / "home"
            home.mkdir()
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.install(
                    "claude", module, home, "linux", "personal", "", "work", ""
                )
            self.assertEqual(rc, 0)
            self.assertFalse((home / ".claude").exists())
            self.assertIn("skip", output.getvalue())

    def test_install_inactive_removes_leaf_link(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "claude"
            make_module(module, {".claude/settings.json": "x"})
            home = Path(d) / "home"
            home.mkdir()
            (home / ".claude").mkdir()
            target = home / ".claude" / "settings.json"
            target.symlink_to((module / ".claude/settings.json").resolve())
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.install(
                    "claude", module, home, "linux", "personal", "", "work", ""
                )
            self.assertEqual(rc, 0)
            self.assertFalse(target.exists())
            self.assertFalse((home / ".claude").exists())
            self.assertIn("skip", output.getvalue())

    def test_install_inactive_removes_dir_link(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "claude"
            make_module(module, {".claude/settings.json": "x"})
            home = Path(d) / "home"
            home.mkdir()
            (home / ".claude").symlink_to(module / ".claude")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.install(
                    "claude", module, home, "linux", "personal", "", "work", ""
                )
            self.assertEqual(rc, 0)
            self.assertFalse((home / ".claude").is_symlink())
            self.assertIn("skip", output.getvalue())

    def test_install_force_backs_up_real_file(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "git"
            make_module(module, {".gitconfig": "x"})
            home = Path(d) / "home"
            home.mkdir()
            target = home / ".gitconfig"
            target.write_text("real")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.install(
                    "git", module, home, "linux", "personal", "", "", "", force=True
                )
            self.assertEqual(rc, 0)
            self.assertTrue(target.is_symlink())
            backups = list((home / ".dotfiles-backup").glob("*/.gitconfig"))
            self.assertEqual(len(backups), 1)
            self.assertEqual(backups[0].read_text(), "real")

    def test_install_force_refuses_parent_symlink(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "swappy"
            make_module(module, {".config/swappy/config": "x"})
            home = Path(d) / "home"
            home.mkdir()
            (home / ".config").mkdir()
            (home / ".config" / "swappy").symlink_to(module / ".config" / "swappy")
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.install(
                    "swappy", module, home, "linux", "personal", "", "", "", force=True
                )
            self.assertEqual(rc, 1)
            self.assertTrue((module / ".config/swappy/config").exists())
            self.assertTrue((home / ".config/swappy").is_symlink())
            self.assertFalse((home / ".dotfiles-backup").exists())

    def test_uninstall_removes_link(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "swappy"
            make_module(module, {".config/swappy/config": "x"})
            home = Path(d) / "home"
            home.mkdir()
            dotctl.install("swappy", module, home, "linux", "personal", "", "", "")
            target = home / ".config/swappy/config"
            self.assertTrue(target.is_symlink())
            rc = dotctl.uninstall(
                "swappy", module, home, "linux", "personal", "", "", ""
            )
            self.assertEqual(rc, 0)
            self.assertFalse(target.exists())
            self.assertFalse((home / ".config/swappy").exists())

    def test_uninstall_keeps_real_file(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "git"
            make_module(module, {".gitconfig": "x"})
            home = Path(d) / "home"
            home.mkdir()
            target = home / ".gitconfig"
            target.write_text("real")
            rc = dotctl.uninstall(
                "git", module, home, "linux", "personal", "", "", ""
            )
            self.assertEqual(rc, 0)
            self.assertEqual(target.read_text(), "real")


class LegacyTest(unittest.TestCase):
    def test_scan_finds_dangling(self):
        with tempfile.TemporaryDirectory() as d:
            repo = Path(d) / "repo"
            repo.mkdir()
            home = Path(d) / "home"
            home.mkdir()
            link = home / "old"
            link.symlink_to(repo / "gone")
            found = dotctl.scan_legacy(repo, home, owned=set(), roots=[(home, 1)])
            self.assertEqual(
                [(str(item.path), item.state) for item in found],
                [(str(link), "dangling")],
            )

    def test_scan_ignores_outside_repo(self):
        with tempfile.TemporaryDirectory() as d:
            repo = Path(d) / "repo"
            repo.mkdir()
            home = Path(d) / "home"
            home.mkdir()
            other = Path(d) / "other"
            other.write_text("x")
            (home / "outside").symlink_to(other)
            found = dotctl.scan_legacy(repo, home, owned=set(), roots=[(home, 1)])
            self.assertEqual(found, [])

    def test_scan_ignores_owned(self):
        with tempfile.TemporaryDirectory() as d:
            repo = Path(d) / "repo"
            repo.mkdir()
            home = Path(d) / "home"
            home.mkdir()
            source = repo / "config"
            source.write_text("x")
            link = home / "config"
            link.symlink_to(source)
            found = dotctl.scan_legacy(repo, home, owned={link}, roots=[(home, 1)])
            self.assertEqual(found, [])

    def test_remove_legacy_refuses_real_file(self):
        with tempfile.TemporaryDirectory() as d:
            repo = Path(d) / "repo"
            repo.mkdir()
            home = Path(d) / "home"
            home.mkdir()
            target = repo / "gone"
            target.write_text("x")
            path = home / "link"
            path.write_text("real")
            entry = dotctl.LegacyLink(
                path=path, target=target, repo_root=repo, state="live"
            )
            self.assertEqual(dotctl.remove_legacy([entry]), 0)
            self.assertTrue(path.exists())

    def test_remove_legacy_removes_symlink(self):
        with tempfile.TemporaryDirectory() as d:
            repo = Path(d) / "repo"
            repo.mkdir()
            home = Path(d) / "home"
            home.mkdir()
            target = repo / "gone"
            target.write_text("x")
            path = home / "link"
            path.symlink_to(target)
            entry = dotctl.LegacyLink(
                path=path, target=target, repo_root=repo, state="live"
            )
            self.assertEqual(dotctl.remove_legacy([entry]), 1)
            self.assertFalse(path.is_symlink())


class StatusTest(unittest.TestCase):
    def test_inactive_reports_stale(self):
        with tempfile.TemporaryDirectory() as d:
            module = Path(d) / "claude"
            make_module(module, {".claude/settings.json": "x"})
            home = Path(d) / "home"
            home.mkdir()
            (home / ".claude").mkdir()
            target = home / ".claude" / "settings.json"
            target.symlink_to((module / ".claude/settings.json").resolve())
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.status(
                    "claude", module, home, "linux", "personal", "", "work", ""
                )
            self.assertEqual(rc, 1)
            self.assertIn("stale", output.getvalue())


class CheckTest(unittest.TestCase):
    def test_check_clean(self):
        with tempfile.TemporaryDirectory() as d:
            repo = Path(d)
            write_tree(
                repo,
                {
                    "a/Makefile": "include ../mk/deploy.mk\n",
                    "a/.config/foo": "x",
                    "b/README.md": "x",
                },
            )
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.check(repo, non_modules=set())
            self.assertEqual(rc, 0)

    def test_check_collision(self):
        with tempfile.TemporaryDirectory() as d:
            repo = Path(d)
            write_tree(
                repo,
                {
                    "a/Makefile": "include ../mk/deploy.mk\n",
                    "a/.config/foo": "x",
                    "b/Makefile": "include ../mk/deploy.mk\n",
                    "b/.config/foo": "x",
                },
            )
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.check(repo, non_modules=set())
            self.assertEqual(rc, 1)
            self.assertIn("collision", output.getvalue())

    def test_check_coverage(self):
        with tempfile.TemporaryDirectory() as d:
            repo = Path(d)
            write_tree(repo, {"c/.config/foo": "x"})
            subprocess.run(["git", "init", "-q"], cwd=repo, check=True)
            subprocess.run(["git", "add", "-A"], cwd=repo, check=True)
            output = io.StringIO()
            with contextlib.redirect_stdout(output):
                rc = dotctl.check(repo, non_modules=set())
            self.assertEqual(rc, 1)
            self.assertIn("no Makefile", output.getvalue())


if __name__ == "__main__":
    unittest.main()

#!/usr/bin/env python3
"""Resolve and inspect dotfiles modules.

Phase 1 covers discovery and `describe`. Link classification lands in the
next slice.
"""

from __future__ import annotations

import argparse
import subprocess
import sys
from collections import Counter
from dataclasses import dataclass
from datetime import datetime
from pathlib import Path


def normalize_os(value: str) -> str:
    return value.strip().lower()


def skip_reason(
    module: str,
    os_name: str,
    profile: str,
    platforms: str,
    profiles: str,
    skip: str,
) -> str | None:
    """Return why a module is inactive, or None when it should deploy.

    `platforms`, `profiles` and `skip` are space-separated lists. An empty
    list means "any".
    """
    skips = skip.strip().split()
    if module in skips:
        return f"config: SKIP"

    plats = platforms.split()
    if plats and os_name not in plats:
        return f"platform: {platforms}"

    profs = profiles.split()
    if profs and profile not in profs:
        return f"profile: {profiles}"

    return None


def blocking_symlink(target: Path, home: Path) -> Path | None:
    """Return the first symlinked directory between `home` and `target`."""
    try:
        rel = target.relative_to(home)
    except ValueError:
        return None
    cur = home
    for part in rel.parts[:-1]:
        cur = cur / part
        if cur.is_symlink():
            return cur
    return None


def classify(target: Path, source: Path, home: Path) -> str:
    """Classify the link at `target` against the module's `source`."""
    if blocking_symlink(target, home):
        return "wrong-target"
    if not target.exists() and not target.is_symlink():
        return "missing"
    if target.is_symlink():
        if target.resolve(strict=False) == source.resolve(strict=False):
            return "ok"

        if not target.exists():
            return "dangling"

        return "wrong-target"
    return "real-file"


@dataclass(frozen=True)
class LegacyLink:
    path: Path
    target: Path
    repo_root: Path
    state: str


def _walk_links(root: Path, max_depth: int):
    if not root.is_dir() or root.is_symlink():
        return
    stack = [(root, 0)]
    while stack:
        current, depth = stack.pop()
        if depth >= max_depth:
            continue
        try:
            entries = list(current.iterdir())
        except OSError:
            continue
        for entry in entries:
            if entry.is_symlink():
                yield entry
            elif entry.is_dir():
                stack.append((entry, depth + 1))


def scan_legacy(
    repo_root: Path,
    home: Path,
    owned: set[Path],
    roots: list[tuple[Path, int]] | None = None,
) -> list[LegacyLink]:
    repo = repo_root.resolve()
    if roots is None:
        roots = [
            (home, 1),
            (home / ".config", 3),
            (home / ".local" / "bin", 1),
            (home / ".claude", 2),
            (home / ".tmux", 2),
        ]

    found = []
    for root, depth in roots:
        for path in _walk_links(root, depth):
            target = path.resolve(strict=False)
            if not target.is_relative_to(repo):
                continue
            if path in owned:
                continue
            state = "live" if target.exists() else "dangling"
            found.append(LegacyLink(path, target, repo, state))
    return sorted(found, key=lambda item: str(item.path))


def remove_legacy(entries: list[LegacyLink]) -> int:
    """Remove only links that still point inside the repo.

    Never touches a real file.
    """
    removed = 0
    for entry in entries:
        if not entry.path.is_symlink():
            continue
        if not entry.path.resolve(strict=False).is_relative_to(entry.repo_root):
            continue
        entry.path.unlink()
        removed += 1
    return removed


def deploy_entries(module_dir: Path) -> list[str]:
    """Return the module-relative paths this module deploys.

    The set is "what git would commit" minus module-root metadata, so
    gitignored runtime state never enters the deploy graph.
    """
    raw = subprocess.run(
        [
            "git",
            "ls-files",
            "--cached",
            "--others",
            "--exclude-standard",
            "-z",
            "--",
            ".",
        ],
        cwd=module_dir,
        check=True,
        capture_output=True,
    ).stdout

    paths = []
    for item in raw.split(b"\0"):
        if not item:
            continue
        rel = item.decode()
        if "/" not in rel:
            if rel == "Makefile" or rel == "AGENTS.md" or rel == ".gitignore":
                continue
            if rel.endswith(".mk") or rel.startswith("README"):
                continue
        full = module_dir / rel
        if not full.exists() and not full.is_symlink():
            continue
        paths.append(rel)
    return sorted(paths)


def display_path(path: Path, home: Path) -> str:
    try:
        return "~/" + str(path.relative_to(home))
    except ValueError:
        return str(path)


def backup_path(home: Path, rel: str) -> Path:
    stamp = datetime.now().strftime("%Y%m%d-%H%M%S")
    return home / ".dotfiles-backup" / stamp / rel


def status(
    module: str,
    module_dir: Path,
    home: Path,
    os_name: str,
    profile: str,
    platforms: str,
    profiles: str,
    skip: str,
) -> int:
    reason = skip_reason(module, os_name, profile, platforms, profiles, skip)
    if reason:
        stale = _owned_links(module_dir, home)
        if not stale:
            print(f"{module}: skip ({reason})")
            return 0
        print(f"{module}: stale ({len(stale)} links, {reason})")
        for path in stale:
            print(f"  stale        {display_path(path, home)}")
        return 1

    results = [
        (rel, classify(home / rel, module_dir / rel, home))
        for rel in deploy_entries(module_dir)
    ]
    bad = [(rel, state) for rel, state in results if state != "ok"]
    if not bad:
        print(f"{module}: ok ({len(results)})")
        return 0

    counts = Counter(state for _, state in results)
    summary = ", ".join(f"{n} {state}" for state, n in sorted(counts.items()))
    print(f"{module}: drift ({summary})")
    for rel, state in bad:
        print(f"  {state:<12} {display_path(home / rel, home)}")
    return 1


def plan(
    module: str,
    module_dir: Path,
    home: Path,
    os_name: str,
    profile: str,
    platforms: str,
    profiles: str,
    skip: str,
) -> int:
    reason = skip_reason(module, os_name, profile, platforms, profiles, skip)
    if reason:
        stale = _owned_links(module_dir, home)
        if not stale:
            print(f"{module}: skip ({reason})")
        else:
            for path in stale:
                print(f"  stale        {display_path(path, home)}")
        return 0

    for rel in deploy_entries(module_dir):
        state = classify(home / rel, module_dir / rel, home)
        print(f"  {state:<12} {display_path(home / rel, home)}")
    return 0


def _owned_links(module_dir: Path, home: Path) -> list[Path]:
    """Links in `home` that belong to this module, including old dir links."""
    root = module_dir.resolve()
    found: set[Path] = set()
    for rel in deploy_entries(module_dir):
        source = (module_dir / rel).resolve()
        target = home / rel
        blocker = blocking_symlink(target, home)
        if blocker is not None:
            if blocker.resolve(strict=False).is_relative_to(root):
                found.add(blocker)
            continue
        if target.is_symlink() and target.resolve(strict=False) == source:
            found.add(target)
    return sorted(found)


def remove_owned(module_dir: Path, home: Path) -> int:
    root = module_dir.resolve()
    removed = 0
    for path in _owned_links(module_dir, home):
        if not path.is_symlink():
            continue
        if not path.resolve(strict=False).is_relative_to(root):
            continue
        path.unlink()
        removed += 1
        parent = path.parent
        while parent != home and parent.is_dir() and not any(parent.iterdir()):
            parent.rmdir()
            parent = parent.parent
    return removed


def install(
    module: str,
    module_dir: Path,
    home: Path,
    os_name: str,
    profile: str,
    platforms: str,
    profiles: str,
    skip: str,
    force: bool = False,
) -> int:
    reason = skip_reason(module, os_name, profile, platforms, profiles, skip)
    if reason:
        removed = remove_owned(module_dir, home)
        suffix = f"; removed {removed}" if removed else ""
        print(f"{module}: skip ({reason}){suffix}")
        return 0

    linked = 0
    ok = 0
    conflicts = 0
    for rel in deploy_entries(module_dir):
        source = (module_dir / rel).resolve()
        target = home / rel
        state = classify(target, source, home)
        if state == "ok":
            ok += 1
        elif state == "missing":
            target.parent.mkdir(parents=True, exist_ok=True)
            target.symlink_to(source)
            linked += 1
        else:
            blocker = blocking_symlink(target, home)
            if blocker is not None:
                conflicts += 1
                print(
                    f"  conflict   {display_path(target, home)} "
                    f"(parent symlink {display_path(blocker, home)})"
                )
                continue
            if force:
                backup = backup_path(home, rel)
                backup.parent.mkdir(parents=True, exist_ok=True)
                target.rename(backup)
                target.symlink_to(source)
                linked += 1
                print(
                    f"  backed up  {display_path(target, home)} "
                    f"-> {display_path(backup, home)}"
                )
            else:
                conflicts += 1
                print(f"  conflict   {display_path(target, home)} ({state})")
    if conflicts:
        print(f"{module}: linked {linked}, ok {ok}, conflicts {conflicts}")
        return 1
    if linked:
        print(f"{module}: linked {linked}, ok {ok}")
    else:
        print(f"{module}: ok ({ok})")
    return 0


def uninstall(
    module: str,
    module_dir: Path,
    home: Path,
    os_name: str,
    profile: str,
    platforms: str,
    profiles: str,
    skip: str,
) -> int:
    removed = 0
    kept = 0
    for rel in deploy_entries(module_dir):
        source = (module_dir / rel).resolve()
        target = home / rel
        if target.is_symlink() and target.resolve(strict=False) == source:
            target.unlink()
            removed += 1
            parent = target.parent
            while parent != home and parent.is_dir() and not any(parent.iterdir()):
                parent.rmdir()
                parent = parent.parent
        elif target.is_symlink() or target.exists():
            kept += 1
    print(f"{module}: removed {removed}, kept {kept}")
    return 0


def legacy(
    repo_root: Path,
    home: Path,
    non_modules: set[str],
    apply: bool,
) -> int:
    owned = set()
    for module_dir in sorted(repo_root.iterdir()):
        if not module_dir.is_dir() or module_dir.name in non_modules:
            continue
        if not (module_dir / "Makefile").is_file():
            continue
        for rel in deploy_entries(module_dir):
            owned.add(home / rel)

    found = scan_legacy(repo_root, home, owned)
    if not found:
        print("legacy: none")
        return 0

    dangling = sum(1 for item in found if item.state == "dangling")
    live = len(found) - dangling
    print(f"legacy: {len(found)} links ({dangling} dangling, {live} live)")
    for item in found:
        print(f"  {item.state:<9} {display_path(item.path, home)} -> {item.target}")

    if apply:
        removed = remove_legacy(found)
        print(f"removed {removed}")
        return 0
    return 1


def check(repo_root: Path, non_modules: set[str]) -> int:
    issues: list[str] = []
    modules: list[Path] = []

    for path in sorted(repo_root.iterdir()):
        if not path.is_dir() or path.name.startswith(".") or path.name in non_modules:
            continue
        if (path / "Makefile").is_file():
            modules.append(path)
            continue

        raw = subprocess.run(
            ["git", "ls-files", "-z", "--", path.name],
            cwd=repo_root,
            check=True,
            capture_output=True,
        ).stdout
        for item in raw.split(b"\0"):
            if not item:
                continue
            rel = item.decode()
            if rel == f"{path.name}/.gitignore":
                continue
            if rel.startswith(f"{path.name}/."):
                issues.append(f"{path.name}: tracked dot-path {rel} but no Makefile")
                break

    targets: dict[str, list[str]] = {}
    for module in modules:
        for rel in deploy_entries(module):
            targets.setdefault(rel, []).append(module.name)
    for rel, owners in sorted(targets.items()):
        if len(owners) > 1:
            issues.append(f"collision: {rel} claimed by {', '.join(owners)}")

    if issues:
        for issue in issues:
            print(issue)
        return 1
    print("check: ok")
    return 0


def describe(
    module: str,
    os_name: str,
    profile: str,
    platforms: str,
    profiles: str,
    skip: str,
) -> None:
    reason = skip_reason(module, os_name, profile, platforms, profiles, skip)
    if reason:
        print(f"{module}: skip ({reason})")
    else:
        print(f"{module}: deploy")


def add_module_args(p: argparse.ArgumentParser) -> None:
    p.add_argument("--module", required=True)
    p.add_argument("--platform", required=True)
    p.add_argument("--profile", required=True)
    p.add_argument("--platforms", default="")
    p.add_argument("--profiles", default="")
    p.add_argument("--skip", default="")


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="dotctl")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("describe", help="print whether a module deploys")
    add_module_args(p)

    p = sub.add_parser("status", help="classify the module's deployed targets")
    add_module_args(p)
    p.add_argument("--home", default=str(Path.home()))

    p = sub.add_parser("plan", help="print every target and its state")
    add_module_args(p)
    p.add_argument("--home", default=str(Path.home()))

    p = sub.add_parser("install", help="link the module's targets")
    add_module_args(p)
    p.add_argument("--home", default=str(Path.home()))
    p.add_argument("--force", action="store_true")

    p = sub.add_parser("uninstall", help="remove the module's own links")
    add_module_args(p)
    p.add_argument("--home", default=str(Path.home()))

    p = sub.add_parser("legacy", help="find links into the repo that no module owns")
    p.add_argument("--repo-root", default=".")
    p.add_argument("--home", default=str(Path.home()))
    p.add_argument("--non-modules", default="clanker")
    p.add_argument("--apply", action="store_true")

    p = sub.add_parser("check", help="check module coverage and target collisions")
    p.add_argument("--repo-root", default=".")
    p.add_argument("--non-modules", default="clanker")

    args = parser.parse_args(argv)
    if args.command == "check":
        return check(
            repo_root=Path(args.repo_root).resolve(),
            non_modules=set(args.non_modules.split()),
        )
    if args.command == "legacy":
        return legacy(
            repo_root=Path(args.repo_root).resolve(),
            home=Path(args.home).expanduser(),
            non_modules=set(args.non_modules.split()),
            apply=args.apply,
        )

    common = {
        "module": args.module,
        "os_name": normalize_os(args.platform),
        "profile": args.profile,
        "platforms": args.platforms,
        "profiles": args.profiles,
        "skip": args.skip,
    }

    if args.command == "install":
        return install(
            module_dir=Path.cwd(),
            home=Path(args.home).expanduser(),
            force=args.force,
            **common,
        )
    if args.command == "uninstall":
        return uninstall(
            module_dir=Path.cwd(),
            home=Path(args.home).expanduser(),
            **common,
        )
    if args.command == "describe":
        describe(**common)
        return 0
    if args.command in ("status", "plan"):
        fn = status if args.command == "status" else plan
        return fn(
            module_dir=Path.cwd(),
            home=Path(args.home).expanduser(),
            **common,
        )
    return 2


if __name__ == "__main__":
    sys.exit(main())

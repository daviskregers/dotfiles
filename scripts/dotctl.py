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
        print(f"{module}: skip ({reason})")
        return 0

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
        print(f"{module}: skip ({reason})")
        return 0

    for rel in deploy_entries(module_dir):
        state = classify(home / rel, module_dir / rel, home)
        print(f"  {state:<12} {display_path(home / rel, home)}")
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

    args = parser.parse_args(argv)
    common = {
        "module": args.module,
        "os_name": normalize_os(args.platform),
        "profile": args.profile,
        "platforms": args.platforms,
        "profiles": args.profiles,
        "skip": args.skip,
    }

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

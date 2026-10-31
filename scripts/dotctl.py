#!/usr/bin/env python3
"""Resolve and inspect dotfiles modules.

Phase 1 covers discovery and `describe`. Link classification lands in the
next slice.
"""

from __future__ import annotations

import argparse
import sys


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


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="dotctl")
    sub = parser.add_subparsers(dest="command", required=True)

    p = sub.add_parser("describe", help="print whether a module deploys")
    p.add_argument("--module", required=True)
    p.add_argument("--platform", required=True)
    p.add_argument("--profile", required=True)
    p.add_argument("--platforms", default="")
    p.add_argument("--profiles", default="")
    p.add_argument("--skip", default="")

    args = parser.parse_args(argv)
    if args.command == "describe":
        describe(
            args.module,
            normalize_os(args.platform),
            args.profile,
            args.platforms,
            args.profiles,
            args.skip,
        )
        return 0
    return 2


if __name__ == "__main__":
    sys.exit(main())

#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
case "$tmp" in
  "${TMPDIR:-/tmp}"/*) ;;
  *) echo "refusing to use temp dir: $tmp" >&2; exit 1 ;;
esac
trap 'rm -rf -- "$tmp"' EXIT

cd "$root"
HOME="$tmp" make install PROFILE=personal SKIP=
HOME="$tmp" make status PROFILE=personal SKIP=
HOME="$tmp" make uninstall PROFILE=personal SKIP=
HOME="$tmp" make legacy PROFILE=personal SKIP= >/dev/null

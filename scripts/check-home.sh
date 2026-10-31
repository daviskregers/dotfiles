#!/usr/bin/env bash
set -euo pipefail

root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$root"

for profile in $(make -s profiles); do
  tmp="$(mktemp -d)"
  case "$tmp" in
    "${TMPDIR:-/tmp}"/*) ;;
    *) echo "refusing to use temp dir: $tmp" >&2; exit 1 ;;
  esac
  trap 'rm -rf -- "$tmp"' EXIT

  echo "check-home: $profile"
  HOME="$tmp" make install PROFILE="$profile" SKIP=
  HOME="$tmp" make status PROFILE="$profile" SKIP=
  HOME="$tmp" make uninstall PROFILE="$profile" SKIP=
  HOME="$tmp" make legacy PROFILE="$profile" SKIP= >/dev/null

  rm -rf -- "$tmp"
  trap - EXIT
done

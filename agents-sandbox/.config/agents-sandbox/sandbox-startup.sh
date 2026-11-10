#!/usr/bin/env bash
# Startup hook, runs as root on every VM start. The only root step: install system packages the
# runner image lacks, then hand off to clanker-provision.sh as `dev`. One entry point, because the
# docs don't define the order of multiple startup hooks.
set -euo pipefail

if ! command -v make >/dev/null; then
  # When DNS or egress is broken, apt only says "no installation candidate"; probe first so the
  # failure names the host.
  for waited in $(seq 0 30); do
    curl -s -o /dev/null -m 2 https://deb.debian.org/debian/ && break
    [[ $waited -eq 30 ]] && { echo "sandbox-startup: no egress to deb.debian.org after 30s" >&2; exit 1; }
    sleep 1
  done
  echo "sandbox-startup: deb.debian.org ready after ${waited}s"

  export DEBIAN_FRONTEND=noninteractive
  sed -i 's|http://deb.debian.org|https://deb.debian.org|' /etc/apt/sources.list.d/*.sources
  apt-get update -qq
  apt-get install -y -qq --no-install-recommends make >/dev/null
fi

# home: provisioning creates ~/.local/bin; make sure dev can add the bun link there.
chown dev: /home/dev/.local /home/dev/.local/bin

runuser -u dev -- env HOME=/home/dev /home/dev/.local/bin/clanker-provision.sh

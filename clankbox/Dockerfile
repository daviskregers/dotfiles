# clankbox sandbox image — one image, both agents.
#
# Extends the sbx `shell-docker` base (Ubuntu 26.04) — the docker-enabled generic
# variant, so the sandbox has its own in-VM docker daemon for `docker compose` /
# test containers (Q6). It already ships node 22, npm, git, curl, python3/pip3, go,
# ripgrep, sudo, the `agent` user (uid 1000), dockerd, and the sbx proxy env
# (BASH_ENV, NO_PROXY, NPM_CONFIG_PREFIX). sbx supplies each agent's launch command
# + credential injection at run time keyed on `sbx run <agent>`, so the image only
# needs the toolchain + both agent binaries on PATH.
FROM docker/sandbox-templates:shell-docker

# Match the claude-code template's env contract (BASH_ENV is already set by the base;
# point claude at the same persistent file). Coexists with opencode.
ENV CLAUDE_ENV_FILE=/etc/sandbox-persistent.sh

USER root

# Languages the base lacks (node / go / python are already present).
RUN apt-get update && apt-get install -y --no-install-recommends \
      php-cli php-xml \
      elixir \
      lua5.4 luarocks \
    && rm -rf /var/lib/apt/lists/*

# Both agent CLIs + shared LSP / formatter tooling + bun (runs the injected .ts
# hooks: dangerous-command-guard, ai-attribution), installed globally.
RUN npm install -g \
      bun \
      opencode-ai \
      @anthropic-ai/claude-code \
      typescript typescript-language-server @vue/typescript-plugin \
      eslint prettier \
      pyright \
      @johnnymorganz/stylua-bin

# Pre-create the agent-home dirs sbx bind-mounts into (skills, agent config). The
# generic shell-docker base doesn't ship these; without them the bind-mount auto-
# creates e.g. /home/agent/.claude ROOT-owned, and the agent's kit then can't write
# .claude/settings.json ("failed to apply kit"). Owning them as agent fixes it.
RUN install -d -o agent -g agent \
      /home/agent/.claude /home/agent/.claude/skills \
      /home/agent/.config /home/agent/.config/opencode \
      /home/agent/.local/share /home/agent/.local/share/opencode

USER agent

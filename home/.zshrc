eval "$(direnv hook zsh)"

source "$HOME/.homesick/repos/homeshick/homeshick.sh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
    export ZSH="$HOME/.oh-my-zsh"
else
    export ZSH="/usr/share/oh-my-zsh"
fi

if [[ -d "$HOME/.oh-my-zsh-custom" ]]; then
    export ZSH_CUSTOM="$HOME/.oh-my-zsh-custom"
    export ZSH_THEME="custom-theme"
fi

plugins=(git)

source ~/.variables
source $ZSH/oh-my-zsh.sh
source ~/.functions
if [[ -f ~/.edurioalias ]]; then
  source ~/.edurioalias
fi
if [[ -f ~/.custom ]]; then
  source ~/.custom
fi

neofetch

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

# pnpm
export PNPM_HOME=$(dirname $(dirname $(pnpm store path)))
case ":$PATH:" in
  *":$PNPM_HOME:"*) ;;
  *) export PATH="$PNPM_HOME:$PATH" ;;
esac
# pnpm end

tmux-window-name() {
    if [ -z "$TMUX_PLUGIN_MANAGER_PATH" ]; then
    else
        ($TMUX_PLUGIN_MANAGER_PATH/tmux-window-name/scripts/rename_session_windows.py &)
    fi
}

add-zsh-hook chpwd tmux-window-name

export PATH="$PATH:$(go env GOBIN):$(go env GOPATH)/bin"

alias ls='ls --color=auto'
alias l='ls -lah'

alias infra='tmuxp load ~/projects/tmuxp-layouts/infra.yaml'
alias tksv='tmux kill-server'

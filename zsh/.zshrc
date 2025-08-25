# eval "$(direnv hook zsh)"

if [[ -d "/usr/share/oh-my-zsh" ]]; then
    export ZSH="/usr/share/oh-my-zsh"
else
    export ZSH="$HOME/.oh-my-zsh"
fi

if [[ -d "$HOME/.oh-my-zsh-custom" ]]; then
    export ZSH_CUSTOM="$HOME/.oh-my-zsh-custom"
    export ZSH_THEME="custom-theme"
fi

plugins=(git)

source ~/.variables
source $ZSH/oh-my-zsh.sh
source ~/.functions

fastfetch

# opencode
export PATH=/Users/daviskregers/.opencode/bin:$PATH

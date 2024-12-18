eval "$(direnv hook zsh)"

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

neofetch
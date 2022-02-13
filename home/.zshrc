source "$HOME/.homesick/repos/homeshick/homeshick.sh"

ARCH=$(uname)
if [[ $(uname) = "Darwin" ]]; then
    export ZSH="$HOME/.oh-my-zsh"
else
    export ZSH="/usr/share/oh-my-zsh"
fi

ZSH_THEME="custom-theme"
plugins=(git)

source $ZSH/oh-my-zsh.sh
source ~/.variables
source ~/.functions
if [[ -f ~/.edurioalias ]]; then
  source ~/.edurioalias
fi

neofetch

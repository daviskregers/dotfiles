source "$HOME/.homesick/repos/homeshick/homeshick.sh"

if [[ -d "$HOME/.oh-my-zsh" ]]; then
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
if [[ -f ~/.custom ]]; then
  source ~/.custom
fi

neofetch

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion

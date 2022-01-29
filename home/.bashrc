# If not running interactively, don't do anything
[[ $- != *i* ]] && return

PS1='[\u@\h \W]\$ '

source ~/.variables
source ~/.functions
source ~/.homesick/repos/homeshick/homeshick.sh

homeshick --quiet refresh

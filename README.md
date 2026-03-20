# dotfiles

My dotfiles.

```console
sudo pacman -S stow
git clone --recurse-submodules git@github.com:daviskregers/dotfiles.git ~/.dotfiles
cd .dotfiles
git config submodule.recurse true
make
```
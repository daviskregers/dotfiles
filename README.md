# dotfiles

My dotfiles.

## Install

```console
sudo pacman -S stow
git clone --recurse-submodules git@github.com:daviskregers/dotfiles.git ~/.dotfiles
cd .dotfiles
git config submodule.recurse true
make
```

## Submodules

### Pull latest changes (including submodules)

```console
git pull
git submodule update --remote --merge
```

`git config submodule.recurse true` (set during install) makes `git pull` automatically update submodule checkouts, but `--remote` is needed to fetch the latest commit from the upstream submodule remote.

### Add a new submodule

```console
git submodule add <url> <path>
git add .gitmodules <path>
git commit
```

Do **not** only edit `.gitmodules` manually — git also needs the gitlink (tree entry) staged via `git submodule add` or the submodule won't be recognized and `git submodule update --init` will silently do nothing.

### Initialize submodules after cloning (if missed)

```console
git submodule update --init
```

Or for a specific submodule:

```console
git submodule update --init <path>
```

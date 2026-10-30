;; -*- lexical-binding: t; -*-

;; ---------------------------------------------------------------------------
;; evil
;; ---------------------------------------------------------------------------

;; these are read when evil loads, so they must be set before the use-package
(setq evil-undo-system 'undo-redo)     ; C-r redo, like vim
(setq evil-want-C-u-scroll t)          ; C-u scrolls up instead of Emacs's prefix arg
(setq evil-search-module 'evil-search) ; vim-style / search, matches stay highlighted (hlsearch)
(setq evil-split-window-below t)       ; splitbelow
(setq evil-vsplit-window-right t)      ; splitright

(require 'package)
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)  ; before the evil block


(use-package evil
  :ensure t
  :pin melpa            ; take evil from MELPA, not the 1.15.0 release
  :config (evil-mode 1))

;; leader / localleader (settings.lua:4-5)
(evil-set-leader '(normal visual) (kbd "SPC"))
(evil-set-leader '(normal visual) (kbd "\\") t)

;; ---------------------------------------------------------------------------
;; clipboard: y/p stay inside Emacs, <leader>y sends to the system clipboard
;; ---------------------------------------------------------------------------

(defvar dk-clipboard-cmd
  (
   cond
   ((executable-find "pbcopy") '("pbcopy"))
   ((executable-find "xclip") '("xclip" "-selection" "clipboard"))
   ((executable-find "wl-copy") '("wl-copy"))
  )
  "clipboard executable"
)

(evil-define-operator dk-get-selection (beg end)
  "Get selection substring"
  (message "%s" (buffer-substring beg end))
  (apply #'call-process-region beg end (car dk-clipboard-cmd)  nil nil nil (cdr dk-clipboard-cmd))
)

(evil-define-key '(normal visual) 'global (kbd "<leader>y") #'dk-get-selection)

;; TODO: highlight the yanked text briefly (TextYankPost + vim.highlight.on_yank)
;;       needs: a package (evil-goggles) or Emacs's built-in `pulse'
;; TODO: :CLoc / <leader>cl, copy "file:line" or "file:start-end" to the clipboard
;;       needs: buffer-file-name, line-number-at-pos, format; reuse dk-clipboard-cmd

;; ---------------------------------------------------------------------------
;; UI
;; ---------------------------------------------------------------------------

(menu-bar-mode -1)

;; relative line numbers (nu + relativenumber)
(setq display-line-numbers-type 'relative)
(global-display-line-numbers-mode 1)

;; cursorline
(global-hl-line-mode 1)

;; scrolloff = 8
(setq scroll-margin 8)
(setq scroll-conservatively 101) ; scroll line by line at the margin instead of jumping half a screen

;; colorcolumn = 80
;; setq-default: like setq, but for per-buffer variables. It sets the value
;; every buffer starts with, instead of only the buffer that's current now.
(setq-default display-fill-column-indicator-column 80)
(global-display-fill-column-indicator-mode 1)

;; TODO: colour of the column line (ColorColumn guibg=#232323)
;;       needs: faces (set-face-attribute), Emacs's version of highlight groups
;; TODO: guicursor = "" (block cursor in insert). evil changes cursor shape
;;       only in GUI Emacs. In a terminal it needs a package (evil-terminal-cursor-changer)
;; TODO: signcolumn = "yes". Terminal Emacs has no fringe; comes with the git gutter package
;; TODO: termguicolors. Emacs detects truecolor from the terminal (COLORTERM/TERM),
;;       check with M-: (display-color-cells) once a theme is in

;; ---------------------------------------------------------------------------
;; editing
;; ---------------------------------------------------------------------------

;; 4 spaces, no tabs (tabstop / shiftwidth / expandtab)
(setq-default indent-tabs-mode nil)
(setq-default tab-width 4)
(setq-default evil-shift-width 4)
;; softtabstop has no direct equivalent. Backspace over spaces deletes one at a time.

;; whitespace: show trailing whitespace (listchars trail + TrailingWhitespace highlight)
(setq-default show-trailing-whitespace t)

;; TODO: listchars tab:» lead:• . needs: whitespace-mode and its whitespace-style list
;; TODO: strip trailing whitespace on save (BufWritePre autocmd)
;;       needs: hooks, i.e. add-hook on before-save-hook with #'delete-trailing-whitespace

;; no swap / backup files
(setq make-backup-files nil) ; backup = false (file~)
(setq auto-save-default nil) ; swapfile = false (#file#)
(setq create-lockfiles nil)  ; swapfile = false (.#file)

;; TODO: undofile (persistent undo across restarts). needs: a package (undo-fu-session)

;; ---------------------------------------------------------------------------
;; mouse
;; ---------------------------------------------------------------------------

(xterm-mouse-mode 1)
;;(setq mouse-wheel-tilt-scroll t) ;; horizontal
(mouse-wheel-mode 1)

;; ---------------------------------------------------------------------------
;; keys
;; ---------------------------------------------------------------------------

;; leave insert mode with C-q (settings.lua:71)
(evil-define-key 'insert 'global (kbd "C-q") #'evil-normal-state)

;; disable arrows
(evil-define-key '(normal visual) 'global (kbd "<up>") #'ignore)
(evil-define-key '(normal visual) 'global (kbd "<down>") #'ignore)
(evil-define-key '(normal visual) 'global (kbd "<left>") #'ignore)
(evil-define-key '(normal visual) 'global (kbd "<right>") #'ignore)

;; quickfix next/prev. Emacs's equivalent is the "next error" list,
;; used by compile, grep, occur, etc.
(evil-define-key 'normal 'global (kbd "]q") #'next-error)
(evil-define-key 'normal 'global (kbd "[q") #'previous-error)

;; TODO: the remaps below all call the key they rebind (n -> "nzzzv",
;;       C-d -> "C-d zz", J -> "mzJ`z", < -> "<gv"). Replaying them as
;;       key strings like "\"+y" would loop forever, because the replayed
;;       n hits the binding again. needs: small commands (defun or
;;       evil-define-command) that call evil's function, then recenter.
;;   - C-d / C-u + recenter (zz)
;;   - n / N + recenter
;;   - J keeps cursor in place
;;   - visual < / > keep the selection
;; TODO: visual J / K move lines down / up. needs: a command (or the drag-stuff package)
;; TODO: visual gs, sort lines and remove duplicates (sort u)
;;       needs: a command calling sort-lines + delete-duplicate-lines
;; TODO: <leader>j / <leader>k location list. No direct Emacs equivalent, revisit with LSP / flymake
;; TODO: <leader>sw swap word with next word. needs: a command (or transpose-words)

;; ---------------------------------------------------------------------------
;; not yet
;; ---------------------------------------------------------------------------

;; TODO: treesitter folding (foldmethod=expr, foldlevelstart=99). needs: treesit + hs-minor-mode or a package
;; TODO: evil-collection (vim keys in help, dired, etc.)
;; TODO: plugins from nvim/lua/plugins/ (telescope, oil, gitsigns, neogit, lsp, ...)
;; TODO: custom-file, so Custom stops writing the block below into this file

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-enabled-themes '(modus-vivendi-tritanopia))
 '(package-selected-packages nil))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

;; Configure package manager
(require 'package)

;; Add Marmalade repo
(add-to-list 'package-archives '("marmalade" . "http://marmalade-repo.org/packages/"))

;; ... and melpa. Melpa packages that exist on marmalade will have
;; precendence.
(add-to-list 'package-archives '("melpa" . "http://melpa.milkbox.net/packages/"))

(package-initialize)

(when (not package-archive-contents)
  (package-refresh-contents))

;; Important packages
(defvar my-pkgs '(starter-kit
                  starter-kit-bindings
                  haskell-mode
                  markdown-mode
                  magit
                  leuven-theme
                  projectile
                  rainbow-delimiters
                  nrepl
                  clojure-mode
                  ace-jump-mode)
  "A list of packages to install at launch.")

(dolist (p my-pkgs)
  (when (not (package-installed-p p))
    (package-install p)))

;; Configure el-get
(require 'cl) 

(add-to-list 'load-path "~/.emacs.d/el-get/el-get")

;; Install el-get if not already present
(unless (require 'el-get nil t)
  (url-retrieve
   "https://github.com/dimitri/el-get/raw/master/el-get-install.el"
   (lambda (s)
     (end-of-buffer)
     (eval-print-last-sexp))))

;; el-get recipes
(setq
 my:el-get-packages
 '(el-get
   switch-window))

(el-get 'sync my:el-get-packages)

;; Set solarized theme
(load-theme 'leuven t)

;; Other general settings

;; Swedish!
(set-language-environment 'Swedish)

;; Enable mouse support on OS X
(unless window-system
  (require 'mouse)
  (xterm-mouse-mode t)
  (global-set-key [mouse-4] '(lambda ()
                              (interactive)
                              (scroll-down 1)))
  (global-set-key [mouse-5] '(lambda ()
                              (interactive)
                              (scroll-up 1)))
  (defun track-mouse (e))

  (setq mouse-sel-mode t)
)

;; Use clipboard properly
(setq x-select-enable-clipboard t)

;; Settings for Emacs.app (Cocoa Emacs)
;; Menu bar doesn't take up additional space, so lets use it.
(menu-bar-mode 1)

;; Don't use Apple's native fullscreen (FIXME: Change with Mavericks)
(setq ns-use-native-fullscreen nil)

;; ... and then enable fullscreen. (This requires a nightly build of
;; Emacs for OS X)
;;(toggle-frame-fullscreen)

;; Navigate windows with M-<arrows>
(windmove-default-keybindings 'meta)
(setq windmove-wrap-around t)

;; Load ace-jump-mode
(autoload
  'ace-jump-mode
  "ace-jump-mode"
  "Emacs quick move minor mode"
  t)

(define-key global-map [?] 'ace-jump-mode)

;; Quick jump back
(autoload
  'ace-jump-mode-pop-mark
  "ace-jump-mode"
  "Ace jump back:-)"
  t)

(eval-after-load "ace-jump-mode"
  '(ace-jump-mode-enable-mark-sync))
(define-key global-map (kbd "C-x ö") 'ace-jump-mode-pop-mark)

;; Configure markdown-mode
(autoload 'markdown-mode "markdown-mode"
  "Major mode for editing Markdown files" t)
(add-to-list 'auto-mode-alist '("\\.txt\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-mode))

;; Configure haskell-mode
;; Enable semi-automatic indentation and font-locking
(add-hook 'haskell-mode-hook 'turn-on-haskell-indentation)
(add-hook 'haskell-mode-hook 'font-lock-mode)

;; Add keybindings to move nested blocks with C-, rsp. C-.
(define-key haskell-mode-map (kbd "C-,") 'haskell-move-nested-left)
(define-key haskell-mode-map (kbd "C-.") 'haskell-move-nested-right)

;; Configure nrepl (Clojure REPL) and clojure-mode
;; Paredit in clojure

(add-hook 'clojure-mode-hook 'paredit-mode)

;; eldoc in clojure
(add-hook 'nrepl-interaction-mode-hook
  'nrepl-turn-on-eldoc-mode)

;; Don't annoy me
(setq nrepl-hide-special-buffers t)
(setq nrepl-popup-stacktraces nil)

;; Paredit in nrepl
(add-hook 'nrepl-mode-hook 'paredit-mode)
(add-hook 'nrepl-mode-hook 'rainbow-delimiters-mode)

;; IRC configuration (erc)
;; Actual servers and such are loaded from irc.el
(require 'erc)
(load "~/.emacs.d/irc")

;; Hiding JOIN, QUIT, PART
(setq erc-hide-list '("JOIN" "PART" "QUIT"))

;; Eshell
;; Start/join
(global-set-key (kbd "C-x m") 'eshell)
;; Always start
(global-set-key (kbd "C-x M") (lambda () (interactive) (eshell t)))

;; Git
(global-set-key (kbd "C-c g") 'magit-status)

(remove-hook 'kill-buffer-query-functions 'server-kill-buffer-query-function)

;; Enable projectile for all things programming
(require 'projectile)
(add-hook 'prog-mode-hook 'projectile-on)

;; Enable rainbow-delimiters for all things programming
(require 'rainbow-delimiters)
(add-hook 'prog-mode-hook 'rainbow-delimiters-mode)

;; Start server for emacsclient
(server-start)

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(custom-safe-themes
   (quote
    ("ea0c5df0f067d2e3c0f048c1f8795af7b873f5014837feb0a7c8317f34417b04" "a234f91f9be6ed40f6ce0e94dce5cea1b9f1ccec2b9ccd42bb71c499867a3fcc" "fc5fcb6f1f1c1bc01305694c59a1a861b008c534cae8d0e48e4d5e81ad718bc6" "1e7e097ec8cb1f8c3a912d7e1e0331caeed49fef6cff220be63bd2a6ba4cc365" "d6a00ef5e53adf9b6fe417d2b4404895f26210c52bb8716971be106550cea257" default)))
 '(erc-modules
   (quote
    (autojoin button completion dcc irccontrols list log match menu move-to-prompt netsplit networks noncommands notifications readonly ring scrolltobottom stamp track)))
 '(ns-alternate-modifier (quote none))
 '(ns-command-modifier (quote meta)))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

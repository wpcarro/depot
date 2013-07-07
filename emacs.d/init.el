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
(defvar my-pkgs '(starter-kit-bindings
                  haskell-mode
                  markdown-mode
                  magit
                  leuven-theme
                  projectile
                  rainbow-delimiters
                  nrepl
                  clojure-mode
                  ace-jump-mode
                  switch-window)
  "A list of packages to install at launch.")

(dolist (p my-pkgs)
  (when (not (package-installed-p p))
    (package-install p)))


(load "~/.emacs.d/init-functions.el")
(load "~/.emacs.d/init-settings.el")

(setq custom-file "~/.emacs.d/init-custom.el")
(load custom-file)

;; IRC configuration (erc)
;; Actual servers and such are loaded from irc.el
(require 'erc)
(load "~/.emacs.d/irc")

;; Seed RNG
(random t)

;; Start server for emacsclient
(server-start)

;; Configure package manager
(require 'package)
(add-to-list 'package-archives
	     '("marmalade" . "http://marmalade-repo.org/packages/") t)
(package-initialize)

(when (not package-archive-contents)
  (package-refresh-contents))

;; Important packages
(defvar my-pkgs '(starter-kit starter-kit-bindings haskell-mode magit color-theme-solarized)
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
(load-theme 'solarized-dark t)

;; Other general settings

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

;; Navigate windows with M-<arrows>
(windmove-default-keybindings 'meta)
(setq windmove-wrap-around t)

;; Configure haskell-mode
;; Enable semi-automatic indentation and font-locking
(add-hook 'haskell-mode-hook 'turn-on-haskell-indentation)
(add-hook 'haskell-mode-hook 'font-lock-mode)

;; Add keybindings to move nested blocks with C-, rsp. C-.
(define-key haskell-mode-map (kbd "C-,") 'haskell-move-nested-left)
(define-key haskell-mode-map (kbd "C-.") 'haskell-move-nested-right)

;; IRC configuration (erc)
;; Actual servers and such are loaded from irc.el
(require 'erc)
(load "~/.emacs.d/irc")

;; Hiding JOIN, QUIT, PART
(setq erc-hide-list '("JOIN" "PART" "QUIT"))

(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(erc-modules (quote (autojoin button completion dcc irccontrols list log match menu move-to-prompt netsplit networks noncommands notifications readonly ring scrolltobottom stamp track))))
(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )

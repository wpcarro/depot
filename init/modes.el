(require 'projectile)

;; Initializes modes I use.

(add-hook 'prog-mode-hook 'esk-add-watchwords)
(add-hook 'prog-mode-hook 'idle-highlight-mode)

;; Configure markdown-mode
(autoload 'markdown-mode "markdown-mode"
  "Major mode for editing Markdown files" t)
(add-to-list 'auto-mode-alist '("\\.txt\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.markdown\\'" . markdown-mode))
(add-to-list 'auto-mode-alist '("\\.md\\'" . markdown-mode))

;; Use auto-complete as completion at point
(defun set-auto-complete-as-completion-at-point-function ()
  (setq completion-at-point-functions '(auto-complete)))

(add-hook 'auto-complete-mode-hook
          'set-auto-complete-as-completion-at-point-function)

;; Configure Erlang mode

(defun erlang-mode-init-setup ()
  (interactive)
  ;; Don't indent after '>' while I'm writing
  (local-set-key ">" 'self-insert-command)
  ;(local-set-key "RET" 'newline)
  )

(add-hook 'erlang-mode-hook 'erlang-mode-init-setup)

;; Enable projectile for all things programming
(add-hook 'prog-mode-hook 'projectile-mode)

;; Enable rainbow-delimiters for all things programming
(add-hook 'prog-mode-hook 'rainbow-delimiters-mode)

;; Enable Paredit in Emacs Lisp mode
(add-hook 'emacs-lisp-mode-hook 'paredit-mode)

;; Always highlight matching brackets
(show-paren-mode 1)

;; Represent undo-history as an actual tree (visualize with C-x u)
(setq undo-tree-mode-lighter "")
(require 'undo-tree)
(global-undo-tree-mode)

;; Keep track of recent files
(recentf-mode)

;; Easily navigate sillycased words
(global-subword-mode 1)

;; Transparently open compressed files
(auto-compression-mode t)

(provide 'modes)

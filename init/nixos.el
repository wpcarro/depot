;; Configure additional settings if this is one of my NixOS machines
;; (i.e. if ExWM is required)
;; -*- lexical-binding: t; -*-

(require 's)
(require 'f)

(defvar is-nixos
  (let ((os-f "/etc/os-release"))
    (s-contains?
     "NixOS" (if (f-file? os-f) (f-read os-f)))))

(defun brightness-up ()
  (interactive)
  (shell-command "exec light -A 10"))

(defun brightness-down ()
  (interactive)
  (shell-command "exec light -U 10"))

(if is-nixos
    (progn
      (message "Running on NixOS, configuring ExWM.")
      (require 'exwm)
      (require 'exwm-config)
      (require 'exwm-cm)

      (fringe-mode 3)

      (setq exwm-workspace-number 2)
      ;; Make class name the buffer name
      (add-hook 'exwm-update-class-hook
                (lambda ()
                  (exwm-workspace-rename-buffer exwm-class-name)))

      ;; 's-r': Reset
      (exwm-input-set-key (kbd "s-r") #'exwm-reset)
      ;; 's-w': Switch workspace
      (exwm-input-set-key (kbd "s-w") #'exwm-workspace-switch)
      ;; 's-N': Switch to certain workspace
      (dotimes (i 10)
        (exwm-input-set-key (kbd (format "s-%d" i))
                            `(lambda ()
                               (interactive)
                               (exwm-workspace-switch-create ,i))))

      ;; Launch applications with completion (dmenu style!)
      (exwm-input-set-key (kbd "s-p") #'helm-run-external-command)

      ;; Toggle between line-mode / char-mode
      (exwm-input-set-key (kbd "C-c C-t C-t") #'exwm-input-toggle-keyboard)

      ;; Brightness keys
      (exwm-input-set-key (kbd "<XF86MonBrightnessDown>") #'brightness-down)
      (exwm-input-set-key (kbd "<XF86MonBrightnessUp>") #'brightness-up)

      ;; Line-editing shortcuts
      (exwm-input-set-simulation-keys
       '(([?\C-d] . delete)
         ([?\C-w] . ?\C-c)))

      ;; Enable EXWM
      (exwm-enable)

      ;; Configure compositor
      (setq exwm-cm-opacity 95)
      (exwm-cm-enable)

      ;; Show time in the mode line
      (display-time-mode)

      ;; Let buffers move seamlessly between workspaces
      (setq exwm-workspace-show-all-buffers t)
      (setq exwm-layout-show-all-buffers t)))

(provide 'nixos)

;;; evil-lispy.el --- Lispy for Evil Mode

;; Copyright (C) 2015 Brandon Carrell

;; Author: Brandon Carrell <brandoncarrell@gmail.com>
;; URL: https://github.com/bcarrell/evil-lispy
;; Version: 0.0.1
;; Keywords: lisp

;; This file is not part of GNU Emacs

;; This file is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; For a full copy of the GNU General Public License
;; see <http://www.gnu.org/licenses/>.

;;; Commentary:
;;
;; evil-lispy defines a minor mode and an additional Evil state for editing
;; Lisp code.  The goal is to encourage a workflow where you can hop between
;; Lispy State for making structured edits using Lispy bindings and the rest
;; of the standard Evil states for general editing.  Where it makes sense,
;; this package redefines a few Lispy bindings, which can be turned on or off
;; by a variable.

;; In addition to providing the Lispy state, this package will do its best to
;; keep your buffer balanced while writing Lisp code.  To that end, it will
;; advise common Evil operations and block them if they will break your buffer
;; or modify them slightly in order to keep everything balanced.
;;
;; It also provides several useful keybindings for editing Lisp in Normal mode.
;;
;; There are several ways to activate Lispy state, denoted as <LISP> in your
;; modeline, all from Normal mode:
;;
;; ) will hop to the right paren and activate Lispy state
;; ( will hop to the left paren and activate Lispy state
;; >i will hop to the right paren and activate Lispy state
;; <i will hop to the left paren and activate Lispy state
;; gv will mark the current symbol and activate Lispy state

;; Once in Lispy state, use ESC to return to Normal mode.

;;; Code:

(require 'evil)
(require 'lispy)

(put 'evil-define-state 'lisp-indent-function 'defun)

;; ——— State ———————————————————————————————————————————————————————————————————

(evil-define-state lispy
  "An evil state for Lispy, a precision editing mode for Lisp."
  :tag "<L>"
  :message "Entering Lispy state!"
  :cursor ("red" box)
  :suppress-keymap t
  :entry-hook (evil-lispy-state-entry)
  :exit-hook (evil-lispy-state-exit)
  nil)

(defun evil-lispy-state-entry ()
  (remove-hook 'activate-mark-hook #'evil-visual-activate-hook t)
  (lispy-mode 1))

(defun evil-lispy-state-exit ()
  (when (region-active-p) (deactivate-mark))
  (add-hook 'activate-mark-hook #'evil-visual-activate-hook nil t)
  (lispy-mode -1))

(defun evil-lispy-enter-state (direction extra-direction)
  "Return a lambda which enters Lispy state at the DIRECTION side of
the current form.  DIRECTION must be either 'left or 'right."
  (let ((f (intern (concat "lispy-" (symbol-name direction))))
        (g (intern (concat "lispy-" (symbol-name extra-direction)))))
    `(lambda ()
       (interactive)
       (when (looking-at lispy-left) (forward-char))
       (let ((pos (point)))
         (,f 1)
         (when (eq (point) pos) (,g 1)))
       (evil-lispy-state))))

(fset 'evil-lispy-enter-state-left (evil-lispy-enter-state 'left 'backward))
(fset 'evil-lispy-enter-state-right (evil-lispy-enter-state 'right 'forward))

(defun evil-lispy-enter-marked-state ()
  "Enters `lispy-state' with the current symbol under point marked."
  (interactive)
  (evil-lispy-state)
  (lispy-mark-symbol))

(defun evil-lispy-enter-visual-state ()
  "If we're in visual state, enter `lispy-state' with the current region
selected."
  (interactive)
  (let ((start (region-beginning))
        (end (region-end))
        (pos (point)))
    (evil-lispy-state)
    (set-mark (if (eq pos start) end start))))

(defun evil-lispy-enter-insert-state (direction extra-direction)
  "Return a lambda which enters Insert state at the DIRECTION side of
the current form.  DIRECTION must be either 'left or 'right."
  `(lambda ()
     (interactive)
     (funcall (evil-lispy-enter-state ',direction ',extra-direction))
     (evil-insert-state)
     (cond
      ((eq ',direction 'left)
       (forward-char)
       (unless (looking-at "\s")
         (insert ?\s)
         (backward-char)))
      ((eq ',direction 'right)
       (backward-char)
       (unless (looking-back "\s")
         (insert ?\s))))))

(fset 'evil-lispy-enter-insert-state-left
      (evil-lispy-enter-insert-state 'left 'backward))
(fset 'evil-lispy-enter-insert-state-right
      (evil-lispy-enter-insert-state 'right 'forward))

;; ——— Mode ————————————————————————————————————————————————————————————————————

(define-minor-mode evil-lispy-mode
  "A minor mode for integrating Evil and Lispy."
  :lighter " evil-lispy"
  :keymap (make-sparse-keymap)
  :after-hook (evil-normal-state))

;; ——— Text objects ————————————————————————————————————————————————————————————

(evil-define-text-object evil-lispy--outer-form-object (&optional count beg end type)
  (let ((bounds (lispy--bounds-list)))
    (when bounds
      (evil-range (car bounds) (cdr bounds)))))

(evil-define-text-object evil-lispy--inner-form-object (&optional count beg end type)
  (let ((bounds (lispy--bounds-list)))
    (evil-range (1+ (car bounds)) (1- (cdr bounds)))))

(define-key evil-inner-text-objects-map "f" 'evil-lispy--inner-form-object)
(define-key evil-outer-text-objects-map "f" 'evil-lispy--outer-form-object)

;; ——— Operations ——————————————————————————————————————————————————————————————

(defun evil-lispy-describe ()
  (interactive)
  (save-excursion
    (lispy-mark-symbol)
    (lispy-describe-inline)))

;; ——— Keys ————————————————————————————————————————————————————————————————————

(define-key evil-lispy-state-map [escape] 'evil-normal-state)

;; ——— Entering state ——————————————————
(evil-define-key 'normal evil-lispy-mode-map
  "(" #'evil-lispy-enter-state-left
  ")" #'evil-lispy-enter-state-right
  "gv" #'evil-lispy-enter-marked-state
  "<i" #'evil-lispy-enter-insert-state-left
  "<I" #'evil-lispy-enter-insert-state-left
  ">i" #'evil-lispy-enter-insert-state-right
  ">I" #'evil-lispy-enter-insert-state-right)

(evil-define-key 'visual evil-lispy-mode-map
  (kbd "RET") #'evil-lispy-enter-visual-state)

;; ——— Editing operations ——————————————
(evil-define-key 'normal evil-lispy-mode-map
  "D" #'lispy-kill
  "K" #'evil-lispy-describe
  (kbd "M-k") #'lispy-kill-sentence
  (kbd "C-1") #'evil-lispy-describe
  (kbd "C-2") #'lispy-arglist-inline)

;; ——— Insert operations ———————————————
(evil-define-key 'insert evil-lispy-mode-map
  "(" #'lispy-parens
  "[" #'lispy-brackets
  "{" #'lispy-braces
  ")" #'lispy-right-nostring
  "\"" #'lispy-quotes
  (kbd "DEL") #'lispy-delete-backward
  (kbd "M-k") #'lispy-kill-sentence
  (kbd "C-1") #'lispy-describe-inline
  (kbd "C-2") #'lispy-arglist-inline)

(provide 'evil-lispy)

;;; evil-lispy.el ends here

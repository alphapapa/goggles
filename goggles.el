;;; goggles.el --- Pulse modified regions -*- lexical-binding: t -*-

;; Author: Daniel Mendler
;; Created: 2020
;; License: GPL-3.0-or-later
;; Version: 0.1
;; Package-Requires: ((emacs "26"))
;; Homepage: https://github.com/minad/goggles

;; This file is not part of GNU Emacs.

;; This program is free software: you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <http://www.gnu.org/licenses/>.

;;; Commentary:

;; Pulse modified regions

;;; Code:

(require 'pulse)

(defgroup goggles nil
  "Pulse modified regions."
  :group 'editing)

(defface goggles-changed
  '((t (:background "DeepSkyBlue")))
  "Face used highlighting changed text."
  :group 'goggles)

(defface goggles-removed
  '((t (:background "IndianRed" :extend t)))
  "Face for highlighting removed text."
  :group 'goggles)

(defface goggles-added
  '((t (:background "MediumSeaGreen")))
  "Face for highlighting added text."
  :group 'goggles)

(defcustom goggles-pulse-iterations 15
  "Number of iterations in a pulse operation."
  :group 'goggles
  :type 'number)

(defcustom goggles-pulse-delay .02
  "Delay between face lightening iterations."
  :group 'goggles
  :type 'number)

(defcustom goggles-pulse t
  "Enable pulsing."
  :group 'goggles
  :type 'boolean)

(defvar goggles--active 0)
(defvar goggles--changes nil)
(defvar goggles--delta 0)
(defvar goggles--list nil)

(defun goggles--post-command ()
  "Highlight changes after command."
  (when goggles--changes
    (let ((start most-positive-fixnum)
          (end 0)
          (pulse-delay goggles-pulse-delay)
          (pulse-iterations goggles-pulse-iterations)
          (pulse-flag goggles-pulse))
      (dolist (ovl goggles--changes)
        (setq start (min start (overlay-start ovl))
              end (max end (overlay-end ovl)))
        (delete-overlay ovl))
      (pulse-momentary-highlight-region
       start end
       (cond
        ((> goggles--delta 0) 'goggles-added)
        ((< goggles--delta 0) 'goggles-removed)
        (t 'goggles-changed)))
      (setq goggles--changes nil
            goggles--delta 0))))

(defun goggles--after-change (start end len)
  "Remember changed region between START and END.
LEN is the length of the replaced string."
  (when (> goggles--active 0)
    (setq goggles--delta (+ goggles--delta (- end start len)))
    (when (and (/= len 0) (= start end))
      (when (> start (buffer-size))
        (setq start (- start 1)))
      (setq end (1+ start)))
    (push (make-overlay start end nil t nil) goggles--changes)))

(defmacro goggles (name &rest funs)
  "Define goggles NAME for functions FUNS."
  (let ((name (intern (format "goggles-%s" name))))
    `(progn
       ,@(mapcar
          (lambda (f)
            `(defun ,(intern (format "goggles--adv-%s" f)) (orig &rest args)
               (setq goggles--active (1+ goggles--active))
               (unwind-protect (apply orig args)
                 (setq goggles--active (- goggles--active 1)))))
          funs)
       (defun ,name (&optional disable)
         (interactive)
         (if disable
             (progn ,@(mapcar (lambda (f) `(advice-remove #',f #',(intern (format "goggles--adv-%s" f)))) funs))
           ,@(mapcar (lambda (f) `(advice-add #',f :around #',(intern (format "goggles--adv-%s" f)))) funs))
         nil)
       (push #',name goggles--list))))

;;;###autoload
(define-minor-mode goggles-mode "Pulse modified regions."
  :global t
  :lighter " Goggles"
  (if goggles-mode
      (progn
        (add-hook 'post-command-hook #'goggles--post-command)
        (add-hook 'after-change-functions #'goggles--after-change)
        (mapc #'funcall goggles--list))
    (remove-hook 'post-command-hook #'goggles--post-command)
    (remove-hook 'after-change-functions #'goggles--after-change)
    (mapc (lambda (f) (funcall f t)) goggles--list)))

(goggles undo primitive-undo)
(goggles yank yank yank-pop)
(goggles kill kill-region)
(goggles delete delete-region)

(provide 'goggles)

;;; goggles.el ends here

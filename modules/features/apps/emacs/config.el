;;; config.el -*- lexical-binding: t; -*-

(setq user-full-name "Jorrit van der Heide"
      user-mail-address "jorrit@bw20.nl")

;; Match the system font and gruvbox aesthetic used elsewhere (stylix ships
;; gruvbox-material-dark; doom-gruvbox is the closest built-in theme).
(setq doom-font (font-spec :family "JetBrainsMono Nerd Font Mono" :size 16)
      doom-theme 'doom-gruvbox)

(setq display-line-numbers-type 'relative)

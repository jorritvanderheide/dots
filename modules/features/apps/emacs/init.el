;;; init.el -*- lexical-binding: t; -*-

;; Doom module selection. Enabled modules are built into the nix store by
;; nix-doom-emacs-unstraightened; after editing this file rebuild the system
;; (nixos-rebuild switch) rather than running `doom sync`.

(doom! :completion
       (corfu +orderless)          ; in-buffer completion
       (vertico +icons)            ; minibuffer completion

       :ui
       doom                        ; the default look
       doom-dashboard
       hl-todo
       modeline
       ophints
       (popup +defaults)
       vc-gutter
       workspaces

       :editor
       (evil +everything)
       file-templates
       fold
       snippets

       :emacs
       (dired +icons)
       electric
       undo
       vc

       :term
       vterm

       :checkers
       syntax

       :tools
       direnv
       (eval +overlay)
       lookup
       magit

       :lang
       emacs-lisp
       markdown
       nix
       org
       sh

       :config
       (default +bindings +smartparens))

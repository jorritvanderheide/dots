_: {
  flake.nixosModules.editor =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # Enable nix-ld for the vue extension's language server, which Zed
        # downloads itself as a prebuilt binary rather than getting it from
        # Nix. (The nix extension's LSP, nixd, comes from home.packages
        # below and doesn't need this.)
        programs.nix-ld.enable = true;

        home-manager.sharedModules = [
          {
            programs.zed-editor = {
              enable = true;

              extensions = [
                "jj-lsp"
                "nix"
                "vue"
              ];

              userSettings = {
                agent_servers.claude-acp.type = "registry";
                auto_update = false;
                base_keymap = "VSCode";
                load_direnv = "shell_hook";
                vim_mode = false;

                languages.Nix = {
                  format_on_save = "on";

                  language_servers = [
                    "jj-lsp"
                    "nixd"
                  ];
                };

                # nixd can resolve option names/types/docs for anything
                # reachable from the flake's own evaluated option tree, so
                # e.g. `home-manager.users.jorrit.programs.<TAB>` completes
                # and hovers with real docs. It can't see *into* freeform
                # settings blobs like programs.zed-editor.userSettings
                # itself though -- those are typed as arbitrary JSON on the
                # home-manager side, so there's no Nix-level schema for
                # Zed's own keys (vim_mode, base_keymap, ...) to complete
                # against.
                lsp.nixd.settings = {
                  formatting.command = [ "nixfmt" ];
                  nixpkgs.expr = ''import (builtins.getFlake "/etc/nixos").inputs.nixpkgs { }'';
                  options.nixos.expr = ''(builtins.getFlake "/etc/nixos").nixosConfigurations.rocinante.options'';
                };
              };
            };

            home = {
              sessionVariables.EDITOR = "zeditor --wait";

              packages = with pkgs; [
                nixd
                nixfmt
              ];
            };
          }
        ];

        my.preservation.homeDirectories = [
          ".config/zed"
          ".local/share/zed"
        ];
      };
    };
}

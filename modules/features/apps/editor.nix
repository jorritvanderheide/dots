{
  lib,
  ...
}:
{
  flake.nixosModules.editor =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # Enable nix-ld for dynamically linked binaries (e.g. Zed language servers)
        programs.nix-ld.enable = true;

        home-manager.sharedModules = [
          {
            programs.zed-editor = {
              enable = true;

              extensions = [
                "gruvbox-material"
                "mcp-server-context7"
                "nix"
                "vue"
              ];

              userSettings = {
                auto_update = false;
                base_keymap = "VSCode";
                load_direnv = "shell_hook";
                vim_mode = false;

                # The Nix extension prefers nixd and warns when it's missing;
                # we deliberately ship nil only.
                languages.Nix.language_servers = [
                  "nil"
                  "!nixd"
                ];

                theme = lib.mkForce {
                  dark = "Gruvbox Material";
                  light = "Gruvbox Material";
                  mode = "system";
                };

                agent_servers = {
                  opencode = {
                    type = "custom";
                    name = "opencode";
                    command = "${lib.getExe pkgs.opencode}";
                    args = [ "acp" ];
                  };
                  claude-acp = {
                    type = "registry";
                  };
                };
              };
            };

            home = {
              sessionVariables.EDITOR = "zeditor --wait";

              packages = with pkgs; [
                nil
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

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
                    args = ["acp"];
                  };
                };
              };
            };

            home = {
              sessionVariables.EDITOR = "zeditor --wait";

              packages = with pkgs; [
                nil
                nixd
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

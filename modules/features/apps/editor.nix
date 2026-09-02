_: {
  flake.nixosModules.editor =
    {
      pkgs,
      ...
    }:
    {
      config = {
        # Enable nix-ld for Zed language servers
        programs.nix-ld.enable = true;

        home-manager.sharedModules = [
          {
            programs.zed-editor = {
              enable = true;

              extensions = [
                "nix"
                "vue"
              ];

              userSettings = {
                agent_servers.claude-acp.type = "registry";
                auto_update = false;
                base_keymap = "VSCode";
                load_direnv = "shell_hook";
                vim_mode = false;

                languages.Nix.language_servers = [
                  "nil"
                  "!nixd" # The Nix extension prefers nixd and warns when it's missing.
                ];
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

{
  lib,
  ...
}:
{
  flake.lib = {
    mkMenu =
      {
        colors,
        lib,
        wlr-which-key,
        writeShellScriptBin,
        writeText,
      }:
      menu:
      let
        configFile = writeText "config.yaml" (
          lib.generators.toYAML { } {
            anchor = "center";
            border = "#${colors.base08}ff";
            border_width = 3;
            corner_r = 8;
            font = "JetBrainsMono Nerd Font Mono 11.5";
            inherit menu;
            padding = 24;
            separator = "  ";
          }
        );
      in
      writeShellScriptBin "my-menu" ''
        exec ${lib.getExe wlr-which-key} ${configFile}
      '';

    mkUser =
      {
        extraGroups ? [ ],
        hashedPasswordFile ? null,
        userSecrets ? { },
        userSecretsFile ? null,
        username,
        withModules ? [ ],
      }:
      {
        config,
        pkgs,
        ...
      }:
      {
        programs.fish.enable = true;

        home-manager.users.${username} = {
          home.stateVersion = "26.05";
          imports = withModules;
        };

        # Ensure persistent home directory exists for preservation
        systemd.tmpfiles.rules = [
          "d /persist/home/${username} 0700 ${username} users -"
        ];

        # Configure user-specific sops secrets
        sops.secrets = lib.mkIf (userSecretsFile != null) (
          lib.mapAttrs (
            _name: secretConfig:
            {
              sopsFile = userSecretsFile;
              owner = username;
              group = "users";
            }
            // secretConfig
          ) userSecrets
        );

        users.users.${username} = {
          extraGroups = [ "wheel" ] ++ extraGroups;
          isNormalUser = true;
          shell = pkgs.fish;
        }
        // (
          # Use hashedPasswordFile if provided, otherwise use user_password from userSecrets
          if hashedPasswordFile != null then
            { inherit hashedPasswordFile; }
          else if (userSecrets ? user_password) then
            { hashedPasswordFile = config.sops.secrets.user_password.path; }
          else
            { }
        );
      };
  };
}

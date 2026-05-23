{
  lib,
  ...
}:
{
  flake.lib = {
    mkCloudflaredTunnel =
      {
        tunnelId,
        credentialsFile,
        ingress,
        default ? "http_status:404",
        originRequest ? {
          noTLSVerify = true;
        },
        transportProtocol ? null,
      }:
      {
        services.cloudflared = {
          enable = true;
          tunnels.${tunnelId} = {
            inherit
              credentialsFile
              ingress
              default
              originRequest
              ;
          };
        };
        systemd.services."cloudflared-tunnel-${tunnelId}" = {
          environment = lib.optionalAttrs (transportProtocol != null) {
            TUNNEL_TRANSPORT_PROTOCOL = transportProtocol;
          };
          after = [
            "dnscrypt-proxy.service"
            "nss-lookup.target"
          ];
          wants = [
            "dnscrypt-proxy.service"
            "nss-lookup.target"
          ];
          unitConfig.StartLimitIntervalSec = 0;
          serviceConfig = {
            Restart = lib.mkForce "always";
            RestartSec = "30s";
          };
        };
      };

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

    mkReverseProxy =
      {
        config,
        subdomain,
        port,
        extraLocations ? { },
        locationExtraConfig ? "",
        # SAMEORIGIN (not DENY) so apps that rely on same-origin iframes still work,
        # e.g. Vaultwarden's browser extension popup.
        extraHeaders ? ''
          add_header X-Content-Type-Options "nosniff" always;
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header Referrer-Policy "no-referrer" always;
        '',
      }:
      let
        acmeDomain = config.my.tailscale.acme.domain;
        domain = "${subdomain}.${toString acmeDomain}";
      in
      {
        assertions = [
          {
            assertion = config.my.tailscale.acme.enable;
            message = "${subdomain} reverse proxy requires my.tailscale.acme.enable";
          }
          {
            assertion = acmeDomain != null;
            message = "${subdomain} reverse proxy requires my.tailscale.acme.domain to be set";
          }
        ];

        security.acme.certs.${domain} = { };

        systemd.services.nginx = {
          wants = [ "acme-finished-${domain}.target" ];
          after = [ "acme-finished-${domain}.target" ];
        };

        services.nginx.virtualHosts.${domain} = {
          forceSSL = true;
          useACMEHost = domain;
          extraConfig = extraHeaders;
          locations = {
            "/" = {
              proxyPass = "http://127.0.0.1:${toString port}";
              proxyWebsockets = true;
              recommendedProxySettings = true;
            }
            // lib.optionalAttrs (locationExtraConfig != "") {
              extraConfig = locationExtraConfig;
            };
          }
          // extraLocations;
        };
      };

    mkUser =
      {
        extraGroups ? [ ],
        hashedPasswordFile ? null,
        initialPassword ? null,
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
          else if initialPassword != null then
            { inherit initialPassword; }
          else
            { }
        );
      };
  };
}

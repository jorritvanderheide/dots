{
  inputs,
  lib,
  ...
}:
{
  flake.lib = {
    # pcscd being up doesn't guarantee the YubiKey is enumerated over USB
    # yet, so a first-try decrypt failure may just be a transient boot-order
    # race, not a real problem. Retry a few times before giving up for real.
    #
    # pcscd.service Requires=polkit.service (pulled in by pcsclite-with-polkit),
    # so a polkit hiccup force-stops pcscd right along with it and can exhaust
    # pcscd's own start-limit for the rest of the boot -- give this enough
    # attempts over enough time to outlast that, and nudge pcscd back to a
    # clean state before each retry instead of trusting it to recover alone.
    sopsRetryUnitConfig = {
      StartLimitIntervalSec = 300;
      StartLimitBurst = 20;
    };

    sopsRetryServiceConfig = {
      Restart = "on-failure";
      RestartSec = "3s";
      # Without this, a successful oneshot goes back to "inactive" and
      # `nixos-rebuild switch` (not just a real boot) re-runs it -- fatal
      # if the YubiKey isn't plugged in at switch time, even though the
      # secret was already applied earlier this boot.
      RemainAfterExit = true;
      # systemd services don't get $HOME by default; age-plugin-yubikey needs
      # it set to find its own state, or decryption fails outright.
      Environment = [ "HOME=/root" ];
      ExecStartPre = "-systemctl reset-failed pcscd.service pcscd.socket";
    };

    # A oneshot service that decrypts sops secrets via the YubiKey identity
    # and does something with them -- the shape shared by
    # set-password-root/set-password-<user>/tpm2-luks-enroll/wireless-secrets.
    # Deliberately not sops-nix's own sops.secrets/activation-time install:
    # with boot.initrd.systemd.enable (needed for the ZFS rollback), *every*
    # boot's activation runs chrooted into /sysroot from the initrd, before
    # real systemd/pcscd exist there to reach the YubiKey over PC/SC -- not a
    # first-boot-only problem. This handles that (pcscd ordering + retry) so
    # callers only write the part that's actually theirs: call
    # `sops_extract <key>` in `script` for each secret needed, then use it.
    mkSopsService =
      {
        pkgs,
        description,
        script,
        wantedBy ? [ ],
        extraUnitConfig ? { },
        extraServiceConfig ? { },
      }:
      {
        inherit description wantedBy;
        after = [ "pcscd.service" ];
        wants = [ "pcscd.service" ];
        unitConfig = inputs.self.lib.sopsRetryUnitConfig // extraUnitConfig;
        serviceConfig =
          inputs.self.lib.sopsRetryServiceConfig
          // extraServiceConfig
          // {
            Type = "oneshot";
          };
        path = [ pkgs.age-plugin-yubikey ];
        script = ''
          set -euo pipefail
          # flock serializes every mkSopsService caller against the same
          # physical YubiKey -- without it, several of these all start
          # concurrently after pcscd.service at boot and race for exclusive
          # PC/SC access, so most of them fail every single attempt until
          # they exhaust their restart budget (observed: 35 failures in a
          # row), not just an occasional transient miss.
          sops_extract() {
            SOPS_AGE_KEY_FILE=/etc/sops/yubikey-identity.txt ${lib.getExe' pkgs.util-linux "flock"} /run/lock/sops-yubikey.lock ${lib.getExe' pkgs.sops "sops"} -d --extract "[\"$1\"]" ${inputs.self}/secrets/secrets.yaml
          }
        ''
        + script;
      };

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
          # Bind only to the tailnet IP. nginx keeps a 0.0.0.0:443 listener for
          # the public headscale vhost, but internal services must not answer
          # there: a connection to the public IP hits the 0.0.0.0 socket, which
          # has no server_name match here, so these vhosts stay tailnet-only.
          listenAddresses = [ config.my.tailscale.tailnetIp ];
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
        username,
        withModules ? [ ],
      }:
      {
        pkgs,
        ...
      }:
      let
        # Password precedence: explicit hashedPasswordFile > explicit
        # initialPassword > the conventional secret for this user, decrypted
        # and set by set-password-${username}.service at boot.
        usePasswordSecret = hashedPasswordFile == null && initialPassword == null;
      in
      {
        programs.fish.enable = true;

        home-manager.users.${username} = {
          home.stateVersion = "26.05";
          imports = withModules;
        };

        systemd.tmpfiles.rules = [
          "d /persist/home/${username} 0700 ${username} users -"
        ];

        # root is wiped every boot (impermanence), so this can't be a
        # first-boot-only step -- see mkSopsService for why it's not
        # sops-nix's own sops.secrets/activation-time install.
        systemd.services = lib.mkIf usePasswordSecret {
          "set-password-${username}" = inputs.self.lib.mkSopsService {
            inherit pkgs;
            description = "Set ${username}'s password from sops";
            wantedBy = [ "multi-user.target" ];
            script = ''
              HASH="$(sops_extract user_password_${username})"
              printf '%s:%s\n' "${username}" "$HASH" | ${lib.getExe' pkgs.shadow "chpasswd"} -e
            '';
          };
        };

        users.users.${username} = {
          isNormalUser = true;
          shell = pkgs.fish;

          extraGroups = [
            "nixos"
            "wheel"
          ]
          ++ extraGroups;
        }
        // (
          if hashedPasswordFile != null then
            { inherit hashedPasswordFile; }
          else if initialPassword != null then
            { inherit initialPassword; }
          else
            { }
        );
      };
  };
}

{
  inputs,
  lib,
  ...
}:
{
  flake.lib = {
    # Where a host keeps an age key of its own (sopsExtract), straight on
    # /persist like the SSH host key. On LUKS, so it's as safe as the disk
    # (the TPM only unlocks under our secure boot); the alternative is a
    # YubiKey needed at every boot, or left plugged in for a thief.
    hostAgeKey = "/persist/system/var/lib/sops/age.key";

    # Keys that may SSH into the hosts (the nixos user) and the installer ISO.
    authorizedKeys = [
      "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIFzx+hZiOpD1jBicAGvWOnUWz8MvL3MANPlidpQixGX8 jorrit@rocinante"
    ];

    # The disk the installer wipes, from the facter report: the first one
    # that isn't on USB (a report gathered from a live ISO lists the
    # installer stick too). `device` is its /dev/disk/by-id/<model>_<serial>
    # name: by-diskseq and /dev/sdX are handed out in boot order, so on the
    # live ISO they can point at another disk.
    mainDisk =
      facterReport:
      let
        onUsb = disk: lib.any (d: d == "usb-storage" || d == "uas") (disk.drivers or [ ]);
        info = lib.findFirst (
          disk: !onUsb disk
        ) (throw "facter report has no non-USB disk") facterReport.hardware.disk;
        stable =
          name:
          lib.hasPrefix "/dev/disk/by-id/" name && !lib.hasInfix "-eui." name && !lib.hasInfix "/wwn-" name;
      in
      {
        inherit info;
        device =
          lib.findFirst stable (throw "disk ${info.model or "?"} has no stable by-id name")
            info.unix_device_names;
      };

    # A tailnetVhost at <subdomain>.<my.ingress.domain> that proxies to a local port.
    mkReverseProxy =
      {
        config,
        extraHeaders ? null,
        extraLocations ? { },
        locationExtraConfig ? "",
        port,
        subdomain,
      }:
      let
        domain = "${subdomain}.${config.my.ingress.domain}";
      in
      lib.recursiveUpdate
        (inputs.self.lib.tailnetVhost (
          { inherit config domain; } // lib.optionalAttrs (extraHeaders != null) { inherit extraHeaders; }
        ))
        {
          services.nginx.virtualHosts.${domain}.locations = {
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

    # A oneshot service that decrypts sops secrets via the YubiKey identity
    # and does something with them: the shape shared by
    # set-password-root/set-password-<user>/tpm2-luks-enroll/wireless-secrets.
    # A secret that only needs to be a file is one of `files`
    # ({ "/run/secrets/<name>" = { key; owner ? "root"; }; }), written
    # readable by its owner only.
    # Deliberately not sops-nix's own sops.secrets/activation-time install:
    # with boot.initrd.systemd.enable (needed for the ZFS rollback), *every*
    # boot's activation runs chrooted into /sysroot from the initrd, before
    # real systemd/pcscd exist there to reach the YubiKey over PC/SC. It's not a
    # first-boot-only problem. This handles that (pcscd ordering + retry) so
    # callers only write the part that's actually theirs: call
    # `sops_extract <key>` in `script` for each secret needed, then use it.
    mkSopsService =
      {
        description,
        extraServiceConfig ? { },
        extraUnitConfig ? { },
        files ? { },
        pkgs,
        script ? "",
        wantedBy ? [ ],
      }:
      assert lib.assertMsg (lib.all (lib.hasPrefix "/run/secrets/") (
        lib.attrNames files
      )) "mkSopsService: files go in /run/secrets";
      {
        inherit description wantedBy;
        after = [ "pcscd.service" ];
        unitConfig = inputs.self.lib.sopsRetryUnitConfig // extraUnitConfig;
        wants = [ "pcscd.service" ];

        # The script reads /etc/sops/secrets.yaml, so it doesn't change
        # when a secret does, and a switch would leave the old value in
        # place until the next boot. A copy of just secrets/ changes exactly
        # when a secret does (unlike the whole flake, every commit).
        restartTriggers = [
          (builtins.path {
            name = "secrets";
            path = inputs.self + "/secrets";
          })
        ];

        script = ''
          set -euo pipefail
          sops_extract() {
            ${inputs.self.lib.sopsExtract pkgs} "$1"
          }
        ''
        + lib.optionalString (files != { }) ''
          install -d -m 0755 /run/secrets
        ''
        + lib.concatStrings (
          lib.mapAttrsToList (
            path:
            {
              key,
              owner ? "root",
            }:
            ''
              sops_extract ${key} > ${path}
            ''
            + lib.optionalString (owner != "root") ''
              chown ${owner} ${path}
            ''
          ) files
        )
        + script;

        serviceConfig =
          inputs.self.lib.sopsRetryServiceConfig
          // lib.optionalAttrs (files != { }) { UMask = "0177"; }
          // extraServiceConfig
          // {
            Type = "oneshot";
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

        # root is wiped every boot (impermanence), so this can't be a
        # first-boot-only step.
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

        systemd.tmpfiles.rules = [
          "d /persist/home/${username} 0700 ${username} users -"
        ];

        users.users.${username} = {
          isNormalUser = true;
          shell = pkgs.fish;

          extraGroups = [
            "nixos"
            "systemd-journal"
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

    # Facts more than one host needs.
    site = {
      domain = "bw20.nl";
      lan.subnet = "192.168.1.0/24";

      # Gatus, on dapple (gatus.nix): what every host reports its disks to.
      statusPage = "https://status.bw20.nl";

      vpnDomain = "vpn.bw20.nl";

      dapple = {
        lanIp = "192.168.1.162";

        # Headscale hands out addresses in order, and dapple joined first
        # (docs/install.md).
        tailnetIp = "100.64.0.1";
      };

      # rocinante's documents and dapple's copy (file-sync.nix,
      # syncthing.nix). A device's ID is the hash of its key, which is in
      # its persisted state.
      syncthing = {
        port = 22000;

        devices = {
          dapple = "T5ZF3AC-HREZOUC-4MKGOWC-3PEWHOZ-WT75JQF-UTKPCZ6-2TN4TKZ-OWUXZQE";
          rocinante = "RMKDHFZ-P6LQ5NT-OXRSEGM-5AKMNDZ-LQNUVY2-KKWQZV3-6Q2YBM5-LZALDQQ";
        };
      };
    };

    # Prints one secret from this host's secrets file (/etc/sops/secrets.yaml,
    # see secrets.nix), decrypted with the host's own age key if it has one,
    # or else with whichever YubiKey is plugged in that is a recipient.
    # Callers need HOME set for age-plugin-yubikey.
    #
    # The lock serializes every caller against the same physical YubiKey.
    # Without it, several mkSopsService units all start concurrently after
    # pcscd.service at boot and race for exclusive PC/SC access, so most of
    # them fail every single attempt until they exhaust their restart budget
    # (observed: 35 failures in a row), not just an occasional transient miss.
    sopsExtract =
      pkgs:
      pkgs.writeShellScript "sops-extract" ''
        set -euo pipefail
        exec 9>/run/lock/sops-yubikey.lock
        ${lib.getExe' pkgs.util-linux "flock"} 9
        identity=$(${lib.getExe' pkgs.coreutils "mktemp"})
        trap 'rm -f "$identity"' EXIT
        export PATH=${pkgs.age-plugin-yubikey}/bin:$PATH
        age-plugin-yubikey --identity >"$identity" 2>/dev/null || true
        # sops reads this on top of the file above; a command, so the key
        # itself isn't copied to /tmp or into the environment.
        if [[ -r ${inputs.self.lib.hostAgeKey} ]]; then
          export SOPS_AGE_KEY_CMD="${lib.getExe' pkgs.coreutils "cat"} ${inputs.self.lib.hostAgeKey}"
        fi
        SOPS_AGE_KEY_FILE=$identity ${lib.getExe' pkgs.sops "sops"} -d --extract "[\"$1\"]" /etc/sops/secrets.yaml
      '';

    sopsRetryServiceConfig = {
      # systemd services don't get $HOME by default; age-plugin-yubikey needs
      # it set to find its own state, or decryption fails outright.
      Environment = [ "HOME=/root" ];

      ExecStartPre = "-systemctl reset-failed pcscd.service pcscd.socket";

      # Without this, a successful oneshot goes back to "inactive" and
      # `nixos-rebuild switch` (not just a real boot) re-runs it, which is fatal
      # if the YubiKey isn't plugged in at switch time, even though the
      # secret was already applied earlier this boot.
      RemainAfterExit = true;

      Restart = "on-failure";
      RestartSec = "3s";
    };

    # pcscd being up doesn't guarantee the YubiKey is enumerated over USB
    # yet, so a first-try decrypt failure may just be a transient boot-order
    # race, not a real problem. Retry a few times before giving up for real.
    #
    # pcscd.service Requires=polkit.service (pulled in by pcsclite-with-polkit),
    # so a polkit hiccup force-stops pcscd right along with it and can exhaust
    # pcscd's own start-limit for the rest of the boot. Give this enough
    # attempts over enough time to outlast that, and nudge pcscd back to a
    # clean state before each retry instead of trusting it to recover alone.
    sopsRetryUnitConfig = {
      StartLimitBurst = 20;
      StartLimitIntervalSec = 300;
    };

    # Keys that may run sudo on dapple (ssh-server.nix), instead of the
    # password: a FIDO2 key on each YubiKey, which signs only with a touch.
    # rocinante forwards an agent with just these (yubikey.nix).
    sudoKeys = [
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIMYYBraKSjuNIGKNBS+PZbBgt62xtBdI8sM7db+48RVGAAAAD3NzaDpkYXBwbGUtc3Vkbw== sudo on dapple, YubiKey 29635974"
      "sk-ssh-ed25519@openssh.com AAAAGnNrLXNzaC1lZDI1NTE5QG9wZW5zc2guY29tAAAAIHm7J1sZHLzDlApmO/AvVs6l8Dlj0hiCSoPsNzOirNKgAAAAD3NzaDpkYXBwbGUtc3Vkbw== sudo on dapple, YubiKey 38555351"
    ];

    # nginx access rules for a location or vhost only the tailnet may use.
    # The address it binds to isn't enough: Linux accepts a packet for any
    # local address on any interface, so a LAN device that routes
    # 100.64.0.0/10 via the host's LAN address reaches the tailnet address
    # too. The source can't be faked that way: tailscaled drops tailnet
    # sources that don't arrive on tailscale0.
    tailnetOnly = ''
      allow 100.64.0.0/10;
      deny all;
    '';

    # An nginx vhost at <domain> that only the tailnet reaches: an ACME
    # certificate, and bound to the tailnet IP with tailnetOnly. Its
    # locations are the caller's (mkReverseProxy's proxy).
    tailnetVhost =
      {
        config,
        domain,
        # SAMEORIGIN (not DENY) so apps that rely on same-origin iframes still work,
        # e.g. Vaultwarden's browser extension popup.
        extraHeaders ? ''
          add_header X-Content-Type-Options "nosniff" always;
          add_header X-Frame-Options "SAMEORIGIN" always;
          add_header Referrer-Policy "no-referrer" always;
        '',
      }:
      {
        security.acme.certs.${domain} = { };

        assertions = [
          {
            assertion = config.my.ingress.enable;
            message = "${domain} requires my.ingress.enable";
          }
        ];

        services.nginx.virtualHosts.${domain} = {
          extraConfig = inputs.self.lib.tailnetOnly + extraHeaders;
          forceSSL = true;

          # Bind only to the tailnet IP. nginx still keeps a 0.0.0.0:443
          # listener for the headscale and kobo vhosts, but internal services
          # must not answer there: a connection to the public IP hits the
          # 0.0.0.0 socket, which has no server_name match here, so these
          # vhosts stay tailnet-only.
          listenAddresses = [ config.my.ingress.tailnetIp ];

          useACMEHost = domain;
        };
      };
  };
}

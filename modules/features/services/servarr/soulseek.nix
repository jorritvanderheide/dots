# Soulseek for Lidarr: slskd is the Soulseek client, and Soularr hands it
# Lidarr's wanted albums and Lidarr what it downloaded. Soulseek isn't a
# torrent or Usenet indexer, so it doesn't go through Prowlarr. The rest of
# the stack is in default.nix.
{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.servarr =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.servarr;
      soulseekDir = "${config.my.media-library.dir}/soulseek";
      downloadsDir = "${soulseekDir}/complete";
      port = config.services.slskd.settings.web.port;

      # The version Soularr pins; 0.2 changed the API. A wheel, since the
      # sdist needs setuptools-git-versioning and a git checkout.
      slskd-api = pkgs.python3Packages.buildPythonPackage rec {
        dependencies = [ pkgs.python3Packages.requests ];
        format = "wheel";
        pname = "slskd_api";
        version = "0.1.5";

        src = pkgs.python3Packages.fetchPypi {
          inherit pname version;
          dist = "py3";
          format = "wheel";
          hash = "sha256-3gPCGgtfK2MW+NvycMaFkIW/VS6B7WAkqxkvUdRWpMA=";
          python = "py3";
        };
      };

      # Upstream has no releases, only a Docker image built from main.
      soularrSrc = pkgs.fetchFromGitHub {
        hash = "sha256-a/HufH1y5QOX0jJolz8oVXZvOlCzg41ab+S35ZsWhWk=";
        owner = "mrusse";
        repo = "soularr";
        rev = "2037399aa57433f9032bbae09833439830d2b409";
      };

      python = pkgs.python3.withPackages (ps: [
        ps.music-tag
        ps.pyarr
        slskd-api
      ]);

      # Soularr expands $VARS in it, so the API keys come from the
      # environment. Lidarr and Soularr share the filesystem, so both see
      # the downloads at the same path.
      soularrConfig = pkgs.writeTextDir "config.ini" (
        lib.generators.toINI { } {
          Lidarr = {
            api_key = "$LIDARR_API_KEY";
            download_dir = downloadsDir;
            host_url = "http://127.0.0.1:${toString config.services.lidarr.settings.server.port}";
          };

          # The journal has it already.
          Logging.log_to_file = false;

          # Upstream's list, plus Netherlands and Belgium: Dutch releases
          # are often tagged with those rather than Europe.
          "Release Settings".accepted_countries = lib.concatStringsSep "," [
            "Europe"
            "Netherlands"
            "Belgium"
            "Japan"
            "United Kingdom"
            "United States"
            "[Worldwide]"
            "Australia"
            "Canada"
          ];

          # Its own default searches the first page of the wanted list
          # every run; this works through all of it, a page per run.
          "Search Settings".search_type = "incrementing_page";

          Slskd = {
            api_key = "$SLSKD_API_KEY";
            download_dir = downloadsDir;
            host_url = "http://127.0.0.1:${toString port}";
          };
        }
      );
    in
    {
      options.my.servarr.soulseek.enable = lib.mkEnableOption ''
        slskd, and Soularr feeding Lidarr's wanted albums to it. Requires
        sops secrets `soulseek_username` and `soulseek_password` (any
        unused name logs in as a new account), `slskd_password` (its web
        login), `slskd_api_key` (any 16+ characters, for Soularr) and
        `lidarr_api_key`, from Lidarr's Settings → General.
      '';

      config = lib.mkIf cfg.soulseek.enable {
        users.users.slskd.extraGroups = [ "media" ];

        my.ingress.proxies.soulseek = {
          inherit port;

          status = {
            group = "media";
            name = "slskd";
            path = "/health";
          };
        };

        # Search and transfer history, and Soularr's list of albums Lidarr
        # failed to import. Nothing that needs an offsite copy.
        my.preservation.systemDirectories = [
          {
            directory = "/var/lib/slskd";
            group = "slskd";
            mode = "0700";
            user = "slskd";
          }
          # DynamicUser, like Prowlarr (default.nix).
          {
            directory = "/var/lib/private/soularr";
            mode = "0777";
          }
        ];

        # Downloads only: no shares, and its listen port stays closed, so
        # it reaches only peers that accept incoming connections.
        services.slskd = {
          enable = true;
          environmentFile = config.sops.templates."slskd.env".path;

          settings = {
            shares.directories = [ ];
            web.ip_address = "127.0.0.1";

            # On the media dataset, so Lidarr's import is a rename.
            directories = {
              downloads = downloadsDir;
              incomplete = "${soulseekDir}/incomplete";
            };
          };
        };

        sops.secrets = lib.genAttrs [
          "lidarr_api_key"
          "slskd_api_key"
          "slskd_password"
          "soulseek_password"
          "soulseek_username"
        ] (_: { });

        sops.templates."slskd.env" = {
          restartUnits = [ "slskd.service" ];

          content = ''
            SLSKD_API_KEY=${config.sops.placeholder.slskd_api_key}
            SLSKD_PASSWORD=${config.sops.placeholder.slskd_password}
            SLSKD_SLSK_PASSWORD=${config.sops.placeholder.soulseek_password}
            SLSKD_SLSK_USERNAME=${config.sops.placeholder.soulseek_username}
            SLSKD_USERNAME=${cfg.webuiUser}
          '';
        };

        sops.templates."soularr.env".content = ''
          LIDARR_API_KEY=${config.sops.placeholder.lidarr_api_key}
          SLSKD_API_KEY=${config.sops.placeholder.slskd_api_key}
        '';

        # UMask 0002 on both: Soularr moves slskd's downloads into a folder
        # per album, and Lidarr moves them out of it, each as the media
        # group. Only with the media library mounted: its mount is nofail,
        # and without it, files would land in the root, which a reboot
        # wipes. lib.sandbox on top of nixpkgs' own, which already confines
        # its writes to the download folders: like Lidarr's (default.nix),
        # .NET needs nothing past it.
        systemd.services.slskd = {
          serviceConfig = inputs.self.lib.sandbox // inputs.self.lib.restartAlways // { UMask = "0002"; };
          unitConfig.RequiresMountsFor = [ config.my.media-library.dir ];
        };

        # A run waits for its downloads and Lidarr's import, then exits;
        # the timer starts the next five minutes later, as upstream's
        # Docker image does. systemd keeps it to one at a time, so no lock
        # file.
        systemd.services.soularr = {
          description = "Soularr: Lidarr's wanted albums from Soulseek";
          unitConfig.RequiresMountsFor = [ config.my.media-library.dir ];

          after = [
            "lidarr.service"
            "slskd.service"
          ];

          serviceConfig = inputs.self.lib.sandbox // {
            DynamicUser = true;
            EnvironmentFile = config.sops.templates."soularr.env".path;
            ExecStart = "${python.interpreter} ${soularrSrc}/soularr.py --config-dir ${soularrConfig} --var-dir /var/lib/soularr --no-lock-file";
            ReadWritePaths = [ downloadsDir ];
            StateDirectory = "soularr";
            SupplementaryGroups = [ "media" ];
            Type = "oneshot";
            UMask = "0002";
          };
        };

        systemd.timers.soularr = {
          wantedBy = [ "timers.target" ];

          timerConfig = {
            OnBootSec = "5min";
            OnUnitInactiveSec = "5min";
          };
        };

        systemd.tmpfiles.rules = [
          "d ${soulseekDir} 2775 root media -"
          "d ${downloadsDir} 2775 root media -"
          "d ${soulseekDir}/incomplete 2775 root media -"
        ];
      };
    };
}

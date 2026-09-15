{
  inputs,
  ...
}:
{
  flake.nixosModules.zotero =
    {
      pkgs,
      ...
    }:
    let
      # Zotero plugins aren't packaged in nixpkgs, and both of these ship
      # their XPI unsigned -- fine, since Zotero's greprefs.js already
      # defaults xpinstall.signatures.required to false.
      #
      # home-manager links the contents of this (Firefox-app-ID) directory
      # into <profile>/extensions, where Zotero's add-on manager picks each
      # XPI up by filename, so the name has to be the add-on's own ID.
      mkZoteroPlugin =
        {
          pname,
          version,
          url,
          hash,
          addonId,
        }:
        pkgs.stdenvNoCC.mkDerivation {
          inherit pname version;

          src = pkgs.fetchurl { inherit url hash; };

          dontUnpack = true;

          installPhase = ''
            runHook preInstall
            install -Dm444 $src "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/${addonId}.xpi"
            runHook postInstall
          '';
        };

      # Citekeys, which ZotLit reads for the note filenames.
      better-bibtex = mkZoteroPlugin {
        pname = "zotero-better-bibtex";
        version = "9.0.64";
        addonId = "better-bibtex@iris-advies.com";
        url = "https://github.com/retorquere/zotero-better-bibtex/releases/download/v9.0.64/zotero-better-bibtex-9.0.64.xpi";
        hash = "sha256-hMS1sF/6yanH4v95ZjYSSG93gWkN1ZsSoeYq7Nz6fCc=";
      };

      # ZotLit's Zotero-side companion. The Obsidian plugin reads the
      # library out of zotero.sqlite on its own, so this is only needed to
      # push changes to Obsidian live while Zotero happens to be open.
      zotlit = mkZoteroPlugin {
        pname = "zotero-zotlit";
        version = "2.1.4";
        addonId = "zotlit@aidenlx.site";
        url = "https://github.com/aidenlx/zotlit/releases/download/zt-2.1.4/zotlit-zotero-2.1.4.xpi";
        hash = "sha256-T3CGoDZr83+G984oEADitWAtzUlu8rz6UgEnsZqeBhQ=";
      };
    in
    {
      config = {
        home-manager.sharedModules = [
          # There's no programs.zotero upstream, but Zotero is Gecko-based,
          # so home-manager's generic browser-module generator produces one:
          # profiles.ini with a fixed profile path (no random name to chase)
          # plus a generated user.js. Passing wrappedPackageName rather than
          # unwrappedPackageName matters -- zotero.override takes no `cfg`
          # argument, so the module hands the package through untouched
          # instead of running it through wrapFirefox.
          (import "${inputs.home-manager}/modules/programs/firefox/mkFirefoxModule.nix" {
            modulePath = [
              "programs"
              "zotero"
            ];
            name = "Zotero";
            wrappedPackageName = "zotero";
            # darwin is unused here, but the generator dereferences it
            # unconditionally for darwinDefaultsId, so it can't be omitted.
            platforms.darwin.configPath = "Library/Application Support/Zotero";
            platforms.linux.configPath = ".zotero/zotero";
          })
          (
            {
              config,
              lib,
              ...
            }:
            {
              programs.zotero = {
                enable = true;

                profiles.default = {
                  extensions.packages = [
                    better-bibtex
                    zotlit
                  ];

                  settings = {
                    # Required for add-ons dropped into the profile: without
                    # it they install but sit disabled pending approval.
                    "extensions.autoDisableScopes" = 0;

                    # Stops the bundled LibreOffice-integration installer
                    # from running on every startup. It probes /opt whenever
                    # that directory exists, and /opt is mode 0711 here, so
                    # the scan throws NS_ERROR_FILE_ACCESS_DENIED and the
                    # modal error dialog it raises takes the whole app down
                    # with an IPC fatal error. Preferences > Cite still has
                    # a manual install button, which bypasses this.
                    "extensions.zoteroOpenOfficeIntegration.skipInstallation" = true;

                    # Zotero 10 segfaults indexing HTML snapshots: it loads
                    # them into a hidden browser over a blob: URL, the
                    # parent rejects that as an illegal load and aborts the
                    # process (mozilla::ipc::FatalError). The item stays
                    # queued, so every later launch retries it and dies
                    # again. Saving PDFs is unaffected -- those go through
                    # indexPDF, a different path -- so turn snapshots off
                    # rather than disabling full-text indexing wholesale.
                    "extensions.zotero.automaticSnapshots" = false;

                    # Drives Locate (the green arrow) > Library Lookup.
                    # Taken from Zotero's own resolver directory, which it
                    # reads from zotero.org/support/locate/openurl_resolvers
                    # -- it is the only Radboud entry there. This is an
                    # OpenURL endpoint, so it 400s when opened bare and only
                    # answers with real ?sid=&doi= parameters.
                    #
                    # Note this is *not* the EZproxy path: it hands off to
                    # WorldCat, which then links onward to the licensed copy.
                    # Zotero's own proxy list (the transparent redirection
                    # behind "Find Available PDF" and stored item URLs) lives
                    # in the proxies/proxyHosts tables of zotero.sqlite, not
                    # in prefs, so it cannot be set from here -- Zotero
                    # learns ru.idm.oclc.org by itself the first time a
                    # proxied page is opened, with proxies.autoRecognize on.
                    "extensions.zotero.openURL.resolver" = "https://ru.on.worldcat.org/atoztitles/link";

                    # Extra source for Find Available PDF, which otherwise
                    # only tries doi.org, the item's own url field, Zotero's
                    # Unpaywall-backed OA service and PMC. Semantic Scholar
                    # indexes open copies those miss (arXiv, ACL, author
                    # postprints). It needs no key, and unlike a proxied
                    # resolver it needs no session either, so it actually
                    # works from Zotero's own HTTP stack.
                    #
                    # Passed as a Nix list, not a string: the module runs
                    # non-scalars through toJSON twice, which is exactly the
                    # JSON-encoded-string-in-a-pref that Zotero parses here.
                    #
                    # Zotero hardcodes a 5s timeout per resolver and the
                    # anonymous pool allows ~100 requests per 5 minutes, so
                    # this will miss some items in a bulk run.
                    "extensions.zotero.findPDFs.resolvers" = [
                      {
                        name = "Semantic Scholar";
                        method = "GET";
                        url = "https://api.semanticscholar.org/graph/v1/paper/DOI:{doi}?fields=openAccessPdf";
                        mode = "json";
                        selector = ".openAccessPdf.url";
                        automatic = true;
                      }
                    ];

                    # BBT's own default, pinned rather than left implicit:
                    # changing the key format once the library has items
                    # re-keys all of them and breaks citation keys already
                    # written into documents.
                    "extensions.zotero.translators.better-bibtex.citekeyFormat" = "auth.lower + shorttitle(3,3) + year";
                  };
                };
              };

              # Gecko decides whether to rescan <profile>/extensions from a
              # cached directory state keyed on mtimes, and every file in
              # the Nix store is stamped 1970 -- so a plugin added or bumped
              # here never looks newer than the cache and is silently never
              # picked up, with no error and no log line. Dropping the cache
              # forces the rescan. extensions.json is deliberately left
              # alone: it also holds per-plugin enable/disable state.
              home.activation.zoteroAddonRescan = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run rm -f ${lib.escapeShellArg "${config.home.homeDirectory}/${config.programs.zotero.profilesPath}/${config.programs.zotero.profiles.default.path}/addonStartup.json.lz4"}
              '';
            }
          )
        ];

        my.preservation.homeDirectories = [
          # Profile (prefs, plugin state); the library database and
          # attachment storage live in the separate data directory.
          ".zotero"
          "Zotero"
        ];
      };
    };
}

{
  inputs,
  ...
}:
{
  flake.nixosModules.zotero =
    {
      config,
      pkgs,
      ...
    }:
    let
      # Bound out here on purpose. The home-manager.sharedModules entry
      # rebinds `config` to the home-manager configuration, where my.research
      # does not exist, so reading it inside that submodule would fail.
      research = config.my.research;

      # Zotero plugins aren't packaged in nixpkgs, and they ship their XPI
      # unsigned. That's fine, since Zotero's greprefs.js already
      # defaults xpinstall.signatures.required to false.
      #
      # home-manager links the contents of this (Firefox-app-ID) directory
      # into <profile>/extensions, where Zotero's add-on manager picks each
      # XPI up by filename, so the name has to be the add-on's own ID.
      mkZoteroPlugin =
        {
          addonId,
          hash,
          pname,
          url,
          version,
        }:
        pkgs.stdenvNoCC.mkDerivation {
          inherit pname version;
          dontUnpack = true;
          src = pkgs.fetchurl { inherit url hash; };

          installPhase = ''
            runHook preInstall
            install -Dm444 $src "$out/share/mozilla/extensions/{ec8030f7-c20a-464f-9b0e-13a3a9e97384}/${addonId}.xpi"
            runHook postInstall
          '';
        };

      # Citekeys, which ZotLit reads for the note filenames.
      better-bibtex = mkZoteroPlugin {
        addonId = "better-bibtex@iris-advies.com";
        hash = "sha256-hMS1sF/6yanH4v95ZjYSSG93gWkN1ZsSoeYq7Nz6fCc=";
        pname = "zotero-better-bibtex";
        url = "https://github.com/retorquere/zotero-better-bibtex/releases/download/v9.0.64/zotero-better-bibtex-9.0.64.xpi";
        version = "9.0.64";
      };
    in
    {
      config = {
        home-manager.sharedModules = [
          # There's no programs.zotero upstream, but Zotero is Gecko-based,
          # so home-manager's generic browser-module generator produces one:
          # profiles.ini with a fixed profile path (no random name to chase)
          # plus a generated user.js. Passing wrappedPackageName rather than
          # unwrappedPackageName matters: zotero.override takes no `cfg`
          # argument, so the module hands the package through untouched
          # instead of running it through wrapFirefox.
          (import "${inputs.home-manager}/modules/programs/firefox/mkFirefoxModule.nix" {
            name = "Zotero";
            platforms.linux.configPath = ".zotero/zotero";
            wrappedPackageName = "zotero";

            modulePath = [
              "programs"
              "zotero"
            ];

            # darwin is unused here, but the generator dereferences it
            # unconditionally for darwinDefaultsId, so it can't be omitted.
            platforms.darwin.configPath = "Library/Application Support/Zotero";
          })
          (
            {
              config,
              lib,
              ...
            }:
            {
              # Gecko decides whether to rescan <profile>/extensions from a
              # cached directory state keyed on mtimes, and every file in
              # the Nix store is stamped 1970, so a plugin added or bumped
              # here never looks newer than the cache and is silently never
              # picked up, with no error and no log line. Dropping the cache
              # forces the rescan. extensions.json is deliberately left
              # alone: it also holds per-plugin enable/disable state.
              home.activation.zoteroAddonRescan = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
                run rm -f ${lib.escapeShellArg "${config.home.homeDirectory}/${config.programs.zotero.profilesPath}/${config.programs.zotero.profiles.default.path}/addonStartup.json.lz4"}
              '';

              # zotero-cli, from the Zotero MCP server's package, for me and
              # for Claude Code through the skill below. It reads
              # zotero.sqlite directly, so it works without Zotero running.
              # Read-only: writing needs a key from a one-time
              # `zotero-mcp authorize-local`.
              home.packages = [ inputs.zotero-mcp.packages.${pkgs.stdenv.hostPlatform.system}.zotero-mcp ];

              programs.claude-code = {
                # The commands that only read. edit, delete, add and the
                # other writes still ask.
                settings.permissions.allow = map (command: "Bash(zotero-cli ${command}:*)") [
                  "annotations list"
                  "collections search"
                  "config"
                  "coverage"
                  "get"
                  "notes list"
                  "path"
                  "read"
                  "related"
                  "search"
                ];

                skills.zotero = ''
                  ---
                  name: zotero
                  description: Look up, search and read papers in the user's Zotero library with zotero-cli. Use when a task involves their references, a citekey, a paper's text or annotations, or a literature note in ~/Obsidian/Literature.
                  ---

                  # Zotero

                  `zotero-cli` reads the local Zotero library directly; Zotero
                  doesn't have to be running. Run `zotero-cli <command> --help`
                  for the options. Add `--json` when the output goes into
                  `jq` or a script.

                  ## Finding an item

                  - `zotero-cli search "Shove practice"` matches title, creator
                    and year. It doesn't search inside PDFs; `read --find`
                    below does, one item at a time.
                  - `zotero-cli search --mode citekey <citekey>` resolves a
                    Better BibTeX citekey to the item key.
                  - `zotero-cli get recent --limit 10`, `get collections`,
                    `get collection-items <key>`.

                  Literature notes in `~/Obsidian/Literature/` are named by
                  citekey and carry the item key as `zotero-key` in their
                  frontmatter. The vault's own CLAUDE.md says what may be read
                  and edited there.

                  ## Reading a paper

                  Papers are long. Don't print a whole paper into the
                  conversation.

                  - `zotero-cli read <key> --find "<phrase>"` ranks the pages
                    that mention a phrase, with snippets. Start here.
                  - `zotero-cli read <key> --start-page 3 --end-page 5` reads
                    those pages. `--format image` renders them as PNGs, for
                    tables, figures and formulas.
                  - For the whole text, write it to a file and search that:
                    `zotero-cli get fulltext <key> > /tmp/<key>.md`.
                  - `zotero-cli annotations list --item-key <key>` gives the
                    user's own highlights and comments.

                  ## Citing

                  Better BibTeX keeps every item, under its citekey, in
                  `~/Obsidian/Literature/library.bib`; take BibTeX from there.
                  `zotero-cli get bibtex` makes up its own keys, and
                  `zotero-cli export` doesn't work here. In the vault, cite
                  with `[[citekey]]`.

                  ## Writing

                  Writes (add, edit, notes create, annotations create, delete)
                  aren't set up: they need a key from `zotero-mcp
                  authorize-local`. Ask before any write, and say so if one
                  fails for that reason.
                '';
              };

              programs.zotero = {
                enable = true;

                # Temporary pin, see the nixpkgs-zotero input in flake.nix.
                package = inputs.nixpkgs-zotero.legacyPackages.${pkgs.stdenv.hostPlatform.system}.zotero;

                profiles.default = {
                  extensions.packages = [
                    better-bibtex
                  ];

                  settings =
                    # Drives Locate (the green arrow) > Library Lookup, and
                    # is the one setting here that depends on which
                    # university this is. Zotero keeps a directory of
                    # resolvers at zotero.org/support/locate/openurl_resolvers.
                    #
                    # This is not the EZproxy path. Zotero's own proxy list,
                    # which drives transparent redirection of stored item
                    # URLs, lives in the proxies/proxyHosts tables of
                    # zotero.sqlite rather than in prefs, so it cannot be set
                    # from here at all. Zotero learns the proxy by itself the
                    # first time a proxied page is opened, given
                    # proxies.autoRecognize.
                    lib.optionalAttrs (research.institution.openurlResolver != null) {
                      "extensions.zotero.openURL.resolver" = research.institution.openurlResolver;
                    }
                    // {
                      # Required for add-ons dropped into the profile: without
                      # it they install but sit disabled pending approval.
                      "extensions.autoDisableScopes" = 0;

                      # Zotero 10 segfaults indexing HTML snapshots: it loads
                      # them into a hidden browser over a blob: URL, the
                      # parent rejects that as an illegal load and aborts the
                      # process (mozilla::ipc::FatalError). The item stays
                      # queued, so every later launch retries it and dies
                      # again. Saving PDFs is unaffected (those go through
                      # indexPDF, a different path), so turn snapshots off
                      # rather than disabling full-text indexing wholesale.
                      "extensions.zotero.automaticSnapshots" = false;

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
                          automatic = true;
                          method = "GET";
                          mode = "json";
                          name = "Semantic Scholar";
                          selector = ".openAccessPdf.url";
                          url = "https://api.semanticscholar.org/graph/v1/paper/DOI:{doi}?fields=openAccessPdf";
                        }
                      ];

                      # BBT's own default, pinned rather than left implicit:
                      # changing the key format once the library has items
                      # re-keys all of them and breaks citation keys already
                      # written into documents.
                      "extensions.zotero.translators.better-bibtex.citekeyFormat" = "auth.lower + shorttitle(3,3) + year";

                      # Stops the bundled LibreOffice-integration installer
                      # from running on every startup. It probes /opt whenever
                      # that directory exists, and /opt is mode 0711 here, so
                      # the scan throws NS_ERROR_FILE_ACCESS_DENIED and the
                      # modal error dialog it raises takes the whole app down
                      # with an IPC fatal error. Preferences > Cite still has
                      # a manual install button, which bypasses this.
                      "extensions.zoteroOpenOfficeIntegration.skipInstallation" = true;
                    };
                };
              };

              # Keeps Zotero's local HTTP server (port 23119, which Paper
              # Trail and Better BibTeX's CAYW endpoint use) up without a
              # window. The Obsidian wrapper in notes.nix starts and stops
              # it. Skipped when Zotero is already open, since a second
              # instance cannot share the profile.
              systemd.user.services.zotero-headless = {
                Unit.Description = "Zotero without a window";

                Service = {
                  Environment = "MOZ_HEADLESS=1";
                  ExecCondition = "${pkgs.bash}/bin/sh -c '! ${pkgs.procps}/bin/pgrep -u %u -x zotero-bin'";
                  ExecStart = lib.getExe config.programs.zotero.package;
                };
              };

              # The headless instance holds the profile lock, and a normal
              # launch against it exits 255 without a window, so opening
              # Zotero from the launcher or a zotero:// link stops it first,
              # and brings it back once Zotero quits if Obsidian still holds
              # its lock (see notes.nix). A launch that only hands a link to
              # an open Zotero returns at once; ExecCondition skips the start
              # then. Overrides the package's entry: XDG_DATA_HOME wins over
              # the profile's share/applications. Wrapping the package instead
              # would rebuild the pinned Zotero from source.
              xdg.dataFile."applications/zotero.desktop".source =
                pkgs.runCommand "zotero-stop-headless.desktop" { }
                  ''
                    substitute ${config.programs.zotero.package}/share/applications/zotero.desktop $out \
                      --replace-fail 'Exec=zotero' 'Exec=${
                        lib.getExe (
                          pkgs.writeShellApplication {
                            name = "zotero";

                            text = ''
                              systemctl --user stop zotero-headless.service || true
                              status=0
                              ${lib.getExe config.programs.zotero.package} "$@" || status=$?
                              ${lib.getExe' pkgs.util-linux "flock"} --nonblock --close "$XDG_RUNTIME_DIR/obsidian.lock" true ||
                                systemctl --user start --no-block zotero-headless.service
                              exit $status
                            '';
                          }
                        )
                      }'
                  '';
            }
          )
        ];

        my.research.statePaths = [
          # Profile (prefs, plugin state); the library database and
          # attachment storage live in the separate data directory.
          ".zotero"
          "Zotero"
        ];
      };
    };
}

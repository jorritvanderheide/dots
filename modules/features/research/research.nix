{
  lib,
  ...
}:
{
  # Option surface shared by the reading and writing tools: Zotero, the
  # Obsidian vault, the pandoc toolchain and the PDF reader.
  #
  # It exists so those modules never name a mechanism or an institution
  # directly. They declare what state they need kept and read the library
  # endpoints from here; deciding *how* state is persisted, and *which*
  # university this is, stays with the consuming configuration. That is what
  # makes the set portable to another machine or another person.
  flake.nixosModules.research = {
    options.my.research = {
      vaultPath = lib.mkOption {
        type = lib.types.str;
        default = "Git/obsidian";
        description = ''
          Obsidian vault location, relative to the user's home directory.
        '';
      };

      statePaths = lib.mkOption {
        type = lib.types.listOf lib.types.str;
        default = [ ];
        description = ''
          Home-relative directories holding research state that must survive
          a wipe: libraries, attachments, per-document reading position.

          Modules append to this rather than writing to a persistence
          mechanism themselves. Wire it to whichever one this machine uses,
          e.g. `my.preservation.homeDirectories = config.my.research.statePaths;`
        '';
      };

      institution = {
        ezproxyPrefix = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "https://login.example.idm.oclc.org/login?qurl=";
          description = ''
            EZproxy login endpoint, including the trailing parameter, so a
            target URL can be appended to it directly.

            Use the `login.` host and the `qurl=` parameter if the proxy
            offers both: the plain `url=` form rejects a percent-encoded
            target and silently redirects to the library menu page instead.
          '';
        };

        openurlResolver = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "https://example.on.worldcat.org/atoztitles/link";
          description = ''
            OpenURL resolver for Zotero's Locate > Library Lookup. Zotero
            keeps a directory of these at
            zotero.org/support/locate/openurl_resolvers.
          '';
        };

        librarySearchUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "https://example.on.worldcat.org/search?queryString={searchTerms}";
          description = ''
            Library discovery search, as a browser search-engine template
            with a {searchTerms} placeholder.
          '';
        };

        iconUrl = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "https://www.example.edu/favicon.ico";
          description = ''
            Icon for the library search entries. Proxy and resolver hosts
            often serve no favicon of their own, so this usually points at
            the university's main site.
          '';
        };
      };
    };
  };
}

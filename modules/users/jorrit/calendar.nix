# jorrit's calendars in noctalia, which come from Proton. The user itself
# is in configuration.nix.
{
  lib,
  ...
}:
{
  flake.nixosModules.jorrit =
    {
      config,
      ...
    }:
    let
      accounts = [
        {
          color = "primary";
          id = "jorrit";
          name = "Jorrit";
        }
        {
          color = "secondary";
          id = "jeltje";
          name = "Jeltje";
        }
        {
          color = "tertiary";
          id = "gezamenlijk";
          name = "Gezamenlijk";
        }
      ];
      secret = account: "proton_calendar_${account.id}";
    in
    {
      sops.secrets = lib.genAttrs (map secret accounts) (_: { });

      # The Proton calendar accounts, rendered from sops.
      home-manager.users.jorrit.programs.noctalia.settings = {
        calendar.enabled = true;
        include.files = [ config.sops.templates."noctalia-calendar.toml".path ];
      };

      # Proton Calendar has no CalDAV, only ICS share links, and those
      # embed the calendar's decryption key. Noctalia's ICS accounts only
      # take the link inline as server_url (no password_file like CalDAV),
      # so the whole account table is rendered here and pulled in via
      # noctalia's [include] instead of living in the store.
      sops.templates."noctalia-calendar.toml" = {
        owner = "jorrit";

        content = lib.concatMapStrings (account: ''
          [calendar.account.proton_${account.id}]
          type = "ics"
          name = "${account.name}"
          color = "${account.color}"
          server_url = "${config.sops.placeholder.${secret account}}"

        '') accounts;
      };
    };
}

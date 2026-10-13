# jorrit's calendars in noctalia, which come from Proton. The user itself
# is in configuration.nix.
{
  inputs,
  ...
}:
{
  flake.nixosModules.jorrit =
    {
      pkgs,
      ...
    }:
    {
      # The Proton calendar accounts, rendered from sops by
      # noctalia-calendar-secrets.
      home-manager.users.jorrit.programs.noctalia.settings = {
        calendar.enabled = true;
        include.files = [ "/run/secrets/noctalia-calendar.toml" ];
      };

      # Proton Calendar has no CalDAV, only ICS share links, and those
      # embed the calendar's decryption key. Noctalia's ICS accounts only
      # take the link inline as server_url (no password_file like CalDAV),
      # so the whole account table is rendered here and pulled in via
      # noctalia's [include] instead of living in the store.
      systemd.services.noctalia-calendar-secrets = inputs.self.lib.mkSopsService {
        inherit pkgs;
        description = "Render noctalia Proton Calendar accounts from sops";
        extraServiceConfig.UMask = "0177";
        wantedBy = [ "multi-user.target" ];

        script = ''
          install -d -m 0755 /run/secrets
          account() {
            url="$(sops_extract "proton_calendar_$1")"
            printf '[calendar.account.proton_%s]\ntype = "ics"\nname = "%s"\ncolor = "%s"\nserver_url = "%s"\n\n' \
              "$1" "$2" "$3" "$url"
          }
          {
            account jorrit Jorrit primary
            account jeltje Jeltje secondary
            account gezamenlijk Gezamenlijk tertiary
          } > /run/secrets/noctalia-calendar.toml.tmp
          chown jorrit /run/secrets/noctalia-calendar.toml.tmp
          mv /run/secrets/noctalia-calendar.toml.tmp /run/secrets/noctalia-calendar.toml
        '';
      };
    };
}

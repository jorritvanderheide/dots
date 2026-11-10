{
  inputs,
  ...
}:
{
  # Voice memos from my phone: Syncthing-Fork sends its memo folder to
  # this inbox, send-only, over the tailnet. Only a folder for memos, never
  # the recorder's default one: research recordings and transcripts don't
  # go into the vault (its CLAUDE.md), and memos end up there.
  flake.nixosModules.voice-memos =
    {
      config,
      ...
    }:
    let
      inherit (inputs.self.lib) site;
    in
    {
      config = {
        assertions = [
          {
            assertion = config.services.syncthing.enable;
            message = "voice-memos needs the syncthing feature";
          }
        ];

        services.syncthing.settings = {
          # The phone dials in, as rocinante does, so dapple needs no
          # address for it.
          devices.phone.id = site.syncthing.devices.phone;

          # Deleting a memo on the phone deletes it here too.
          folders.memos = {
            devices = [ "phone" ];
            path = "${config.services.syncthing.dataDir}/memos";
            type = "receiveonly";
          };
        };
      };
    };
}

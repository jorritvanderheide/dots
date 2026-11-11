{
  inputs,
  ...
}:
{
  # Voice memos from my phone, as notes in the vault. Syncthing-Fork sends
  # its memo folder to the inbox, send-only, over the tailnet. For each new
  # recording, whisper.cpp transcribes it on the GPU, a note with the
  # transcript goes into the vault's Notes/, where Loose Ends marks it
  # inbox, and the recording is copied to the archive, which syncs to
  # rocinante's ~/Audio/Voice memos (site.voiceMemos) and which the note
  # links to. Only a folder for memos, never the recorder's default one:
  # research recordings and transcripts don't go into the vault (its
  # CLAUDE.md).
  #
  # A memo is done once the archive has it, so deleting it on the phone
  # only empties the inbox. Deleting it from the archive while the phone
  # still has it makes a second note. A memo that fails is left for the
  # next run, and fails the unit, which unit-health reports.
  flake.nixosModules.voice-memos =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      inherit (inputs.self.lib) site;
      inherit (config.services.syncthing) dataDir;
      archive = "${dataDir}/voice-memos";
      inbox = "${dataDir}/memos";
      notes = "${dataDir}/obsidian/Notes";

      # Multilingual, good at Dutch and English, quantized to 5 bits.
      model = pkgs.fetchurl {
        hash = "sha256-OUIhcJzVrR9AxG5gMcphvOiJMebgiMGIKUxtWlX/p+I=";
        url = "https://huggingface.co/ggerganov/whisper.cpp/resolve/5359861c739e955e79d9a303bcbc70fb988958b1/ggml-large-v3-turbo-q5_0.bin";
      };

      # Finds the speech first, so whisper doesn't make words up out of
      # silence: five quiet seconds came out as "you" without it.
      vadModel = pkgs.fetchurl {
        hash = "sha256-KqJpt4XutTqCmDogUB3ffB2cSOM6tjpBORrGyff7aYc=";
        url = "https://huggingface.co/ggml-org/whisper-vad/resolve/9ffd54a1e1ee413ddf265af9913beaf518d1639b/ggml-silero-v6.2.0.bin";
      };

      recordings = "file:///home/${site.user}/${lib.replaceStrings [ " " ] [ "%20" ] site.voiceMemos}";
    in
    {
      config = {
        assertions = [
          {
            assertion = config.services.syncthing.settings.folders ? obsidian;
            message = "voice-memos needs the vault feature";
          }
        ];

        # It works in Syncthing's files, as Syncthing's user, and a restore
        # stops if something still has them open.
        my.offsite-backup.entries.syncthing.units = [ "voice-memos.service" ];

        services.syncthing.settings = {
          # The phone dials in, as rocinante does, so dapple needs no
          # address for it.
          devices.phone.id = site.syncthing.devices.phone;

          folders = {
            # Deleting a memo on the phone deletes it here too.
            memos = {
              devices = [ "phone" ];
              path = inbox;
              type = "receiveonly";
            };

            voice-memos = {
              devices = [ "rocinante" ];
              path = archive;
            };
          };
        };

        # Each memo as it arrives: Syncthing renames a finished file into
        # place. Hourly too, for one that came in while this was stopped.
        systemd.paths.voice-memos = {
          pathConfig.PathChanged = inbox;
          unitConfig.RequiresMountsFor = [ dataDir ];
          wantedBy = [ "paths.target" ];
        };

        systemd.services.voice-memos = {
          description = "Transcribe new voice memos into the vault";

          # Mesa's shader cache, so the GPU's shaders aren't built again
          # for every memo.
          environment.XDG_CACHE_HOME = "/var/cache/voice-memos";

          path = [
            pkgs.coreutils
            pkgs.ffmpeg-headless
            pkgs.gnused
            pkgs.whisper-cpp-vulkan
          ];

          # The title is the transcript's first eight words, without what a
          # file name can't hold and the punctuation around them; the
          # name stays free until the memo is filed, and Obsidian renames
          # the links. A memo without speech gets no note. whisper prints
          # the transcript too, which stays out of the journal.
          script = ''
            shopt -s nullglob nocaseglob
            tmp=$(mktemp -d)
            failed=0
            for memo in ${inbox}/*.{aac,flac,m4a,mp3,ogg,opus,wav}; do
              name=''${memo##*/}
              if [[ -e "${archive}/$name" ]]; then
                continue
              fi
              : >"$tmp/memo.txt"
              if ! ffmpeg -nostdin -loglevel error -y -i "$memo" -ar 16000 -ac 1 -c:a pcm_s16le "$tmp/memo.wav" ||
                ! whisper-cli --model ${model} --vad --vad-model ${vadModel} --language auto --no-timestamps --no-prints --output-txt --output-file "$tmp/memo" --file "$tmp/memo.wav" >/dev/null; then
                echo "Couldn't transcribe $name" >&2
                failed=1
                continue
              fi
              text=$(tr '\n' ' ' <"$tmp/memo.txt" | sed 's/\[BLANK_AUDIO\]//g; s/  */ /g; s/^ //; s/ $//')
              if [[ -n $text ]]; then
                title=$(cut -d ' ' -f 1-8 <<<"$text" | sed 's/[][\\/:*?"<>|#^]//g; s/^[[:punct:][:space:]]*//; s/[[:punct:][:space:]]*$//')
                title=''${title:-Voice memo}
                note="${notes}/$title.md"
                n=2
                while [[ -e $note ]]; do
                  note="${notes}/$title $n.md"
                  n=$((n + 1))
                done
                printf '\n# %s\n\n[Recording](%s/%s)\n\n%s\n' "$title" "${recordings}" "''${name// /%20}" "$text" >"$note"
              else
                echo "No speech in $name, so no note" >&2
              fi
              cp --preserve=timestamps "$memo" "${archive}/$name"
            done
            exit "$failed"
          '';

          # The GPU's render node, which is open to every user.
          serviceConfig = inputs.self.lib.sandbox // {
            CacheDirectory = "voice-memos";
            DeviceAllow = [ "/dev/dri/renderD128 rw" ];
            Group = "syncthing";
            PrivateDevices = false;
            ProtectSystem = "strict";
            Type = "oneshot";
            UMask = "0077";
            User = "syncthing";

            ReadWritePaths = [
              archive
              notes
            ];
          };
        };

        systemd.timers.voice-memos = {
          timerConfig.OnCalendar = "hourly";
          wantedBy = [ "timers.target" ];
        };
      };
    };
}

{
  inputs,
  ...
}:
{
  perSystem =
    {
      config,
      pkgs,
      system,
      ...
    }:
    {
      # Building the deploy script runs shellcheck, and builds the app with it.
      checks.kobo-deploy = config.packages.kobo-deploy;

      # `kobo-deploy root@<kobo>`, from `nix run .#kobo-deploy`: copies what
      # the Kobo lacks of kobo-app's closure into /nix on its root
      # filesystem, points /nix/var/kobo/current at it, and runs it once.
      # Not a vfat image on /mnt/onboard: Nickel unmounts that partition for
      # USB, which a loop mount on it would block.
      packages.kobo-deploy = pkgs.writeShellApplication {
        name = "kobo-deploy";
        runtimeEnv.KOBO_SYSTEM = "${inputs.kobo-app.packages.${system}.default}";

        runtimeInputs = with pkgs; [
          gnutar
          nix
          openssh
        ];

        text = ''
          target=''${1:?usage: kobo-deploy <ssh destination, like root@192.168.1.40>}

          # One connection for the whole deploy, so a password login asks once.
          control=$(mktemp -d)
          trap 'ssh -o ControlPath="$control/s" -O exit "$target" 2>/dev/null; rm -rf "$control"' EXIT
          on_kobo() {
            ssh -o ControlMaster=auto -o ControlPath="$control/s" -o ControlPersist=60 "$target" "$@"
          }

          # Only the paths the Kobo lacks: glibc rarely changes
          # between deploys.
          present=$(on_kobo 'ls /nix/store 2>/dev/null || true')
          missing=()
          while read -r path; do
            grep -qxF "''${path#/nix/store/}" <<<"$present" || missing+=("''${path#/}")
          done < <(nix-store --query --requisites "$KOBO_SYSTEM")

          # Unpacked beside the store and moved in a path at a time, so an
          # interrupted copy never leaves a half path that looks present.
          if ((''${#missing[@]})); then
            echo "Copying ''${#missing[@]} store paths to $target"
            tar -c -C / "''${missing[@]}" | on_kobo '
              set -e
              rm -rf /nix/.incoming
              mkdir -p /nix/.incoming /nix/store
              tar -x -C /nix/.incoming
              mv /nix/.incoming/nix/store/* /nix/store/
              rm -rf /nix/.incoming
            '
          fi

          on_kobo "mkdir -p /nix/var/kobo && ln -sfn $KOBO_SYSTEM /nix/var/kobo/current && /nix/var/kobo/current/bin/kobo-app"
        '';
      };
    };
}

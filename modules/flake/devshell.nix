{ inputs, ... }:
{
  perSystem =
    {
      config,
      pkgs,
      ...
    }:
    let
      # Helper to create a wrapper for bash scripts with proper PATH
      # Inlines common.sh library to avoid path issues
      mkScript =
        name: script:
        let
          commonLib = builtins.readFile (inputs.self + "/scripts/lib/common.sh");
          scriptContent = builtins.readFile script;
          # Remove shebang and source line from script, add common.sh inline
          cleanedScript = builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] scriptContent;
          finalScript =
            builtins.replaceStrings
              [ "# shellcheck source=lib/common.sh disable=SC1091\nsource \"$(dirname \"$0\")/lib/common.sh\"\n" ]
              [ "# Common library inlined below\n${commonLib}\n" ]
              cleanedScript;
        in
        pkgs.writeShellApplication {
          inherit name;
          runtimeInputs = with pkgs; [
            coreutils
            git
            gawk
            gnugrep
            gnused
            jq
            jujutsu
            nixos-rebuild
            nvd
          ];
          text = finalScript;
        };

      # Rebuild scripts (external files in scripts/)
      nswitch = mkScript "nswitch" (inputs.self + "/scripts/nswitch.sh");
      nboot = mkScript "nboot" (inputs.self + "/scripts/nboot.sh");
      ntest = mkScript "ntest" (inputs.self + "/scripts/ntest.sh");
      nbuild = mkScript "nbuild" (inputs.self + "/scripts/nbuild.sh");
      nupdate = mkScript "nupdate" (inputs.self + "/scripts/nupdate.sh");
      ncheck = mkScript "ncheck" (inputs.self + "/scripts/ncheck.sh");

      # Installation script
      ninstall = mkScript "ninstall" (inputs.self + "/scripts/ninstall.sh");

      # Complex deploy script with common.sh inlined
      ndeploy =
        let
          commonLib = builtins.readFile (inputs.self + "/scripts/lib/common.sh");
          scriptContent = builtins.readFile (inputs.self + "/scripts/ndeploy.sh");
          # Remove shebang and source line from script, add common.sh inline
          cleanedScript = builtins.replaceStrings [ "#!/usr/bin/env bash\n" ] [ "" ] scriptContent;
          finalScript =
            builtins.replaceStrings
              [ "# shellcheck source=lib/common.sh disable=SC1091\nsource \"$(dirname \"$0\")/lib/common.sh\"\n" ]
              [ "# Common library inlined below\n${commonLib}\n" ]
              cleanedScript;
        in
        pkgs.writeShellApplication {
          name = "ndeploy";
          runtimeInputs = with pkgs; [
            coreutils
            gawk
            gnugrep
            gnused
            jq
            nixos-anywhere
            openssh
            sops
            ssh-to-age
            sshpass
          ];
          text = finalScript;
        };
    in
    {
      devShells.default = pkgs.mkShell {
        name = "nixos-config";

        packages = with pkgs; [
          # Custom rebuild scripts
          nswitch
          nboot
          ntest
          nbuild
          nupdate
          ncheck
          ninstall
          ndeploy

          # Development tools
          config.formatter

          # NixOS tools
          nixos-anywhere

          # Utilities
          sbctl
          sops
        ];

        shellHook = ''
          echo "🚀 NixOS Configuration Development Shell"
          echo ""
          echo "Available commands:"
          echo "  nswitch  - Rebuild and switch current system"
          echo "  nboot    - Rebuild for next boot"
          echo "  nbuild   - Build without switching (dry-run)"
          echo "  ntest    - Rebuild and test (no bootloader update)"
          echo "  ninstall - Install NixOS locally on current host"
          echo "  ndeploy  - Deploy NixOS to remote host"
          echo "  nupdate  - Update flake inputs"
          echo "  ncheck   - Check flake outputs"
          echo ""
          echo "Host: ${config.networking.hostName or "unknown"}"
          echo "Flake: $(git rev-parse --show-toplevel 2>/dev/null || pwd)"
          echo ""
        '';
      };
    };
}

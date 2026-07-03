{
  flake.nixosModules.power =
    {
      config,
      lib,
      pkgs,
      ...
    }:
    let
      cfg = config.my.power;

      # Auto-detect CPU vendor from facter report
      cpuVendor =
        let
          facterCpu = config.facter.report.hardware.cpu or null;
          vendorName =
            if facterCpu != null && facterCpu != [ ] then
              (builtins.head facterCpu).vendor_name or null
            else
              null;
        in
        if vendorName == "GenuineIntel" then
          "intel"
        else if vendorName == "AuthenticAMD" then
          "amd"
        else
          null;

      # Detect whether any device in a facter hardware category uses a given
      # kernel driver, so modprobe tunables only emit for matching hardware.
      hasDriver =
        category: driver:
        let
          devices = config.facter.report.hardware.${category} or [ ];
        in
        builtins.any (d: (d.driver_module or null) == driver) devices;
    in
    {
      options.my.power = {
        cpuGovernor = lib.mkOption {
          # intel_pstate=active / amd-pstate=active (set below) only support
          # these two governors; the legacy ondemand/conservative/schedutil
          # require acpi-cpufreq, which we don't use on modern CPUs.
          type = lib.types.enum [
            "performance"
            "powersave"
          ];
          default = "powersave";
          description = "CPU frequency scaling governor";
        };

        laptop = {
          enable = lib.mkEnableOption "laptop-specific power optimizations";
        };
      };

      config = lib.mkMerge [
        {
          powerManagement = {
            enable = true;
            cpuFreqGovernor = lib.mkDefault cfg.cpuGovernor;
          };
        }

        # Laptop-specific settings
        (lib.mkIf cfg.laptop.enable {
          hardware.system76.power-daemon.enable = true;

          boot.extraModprobeConfig = lib.concatStringsSep "\n" (
            lib.optionals (hasDriver "network_controller" "iwlwifi") [
              "options iwlwifi power_save=1"
              "options iwlmvm power_scheme=3"
            ]
            ++ lib.optionals (hasDriver "sound" "snd_hda_intel") [
              "options snd_hda_intel power_save=1 power_save_controller=Y"
            ]
          );

          services = {
            # Disable TLP auto-enabled by nixos-hardware common/pc/laptop;
            # system76-power-daemon is the chosen power manager.
            tlp.enable = lib.mkForce false;

            # system76-power does not react to AC plug/unplug on its own;
            # switch profiles from udev. Coldplug at boot applies the right
            # one on startup too.
            udev.extraRules = ''
              SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="0", RUN+="${pkgs.system76-power}/bin/system76-power profile battery"
              SUBSYSTEM=="power_supply", ATTR{type}=="Mains", ATTR{online}=="1", RUN+="${pkgs.system76-power}/bin/system76-power profile balanced"
            '';

            thermald.enable = cpuVendor == "intel"; # Thermald is Intel-specific
            upower.enable = true;

            system76-scheduler = {
              enable = true;
              settings.cfsProfiles.enable = true;
            };
          };
        })

        # AMD-specific optimizations
        (lib.mkIf (cpuVendor == "amd") {
          boot.kernelParams = [ "amd_pstate=active" ];
        })

        # Intel-specific optimizations
        (lib.mkIf (cpuVendor == "intel") {
          boot.kernelParams = [ "intel_pstate=active" ];
        })
      ];
    };
}

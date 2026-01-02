{
  flake.nixosModules.power =
    {
      config,
      lib,
      ...
    }:
    let
      cfg = config.features.power;

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
    in
    {
      options.features.power = {
        enable = lib.mkEnableOption "power management";

        cpuGovernor = lib.mkOption {
          type = lib.types.enum [
            "performance"
            "powersave"
            "ondemand"
            "conservative"
            "schedutil"
          ];
          default = "schedutil";
          description = "CPU frequency scaling governor";
        };

        laptop = {
          enable = lib.mkEnableOption "laptop-specific power optimizations";
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          {
            powerManagement = {
              enable = true;
              cpuFreqGovernor = lib.mkDefault cfg.cpuGovernor;
            };
          }

          # Laptop-specific settings
          (lib.mkIf cfg.laptop.enable {
            hardware.system76.power-daemon.enable = true;
            powerManagement.powertop.enable = true;

            services = {
              thermald.enable = (cpuVendor == "intel"); # Thermald is Intel-specific
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
        ]
      );
    };
}

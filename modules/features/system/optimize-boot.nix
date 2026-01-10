{
  lib,
  ...
}:
{
  flake.nixosModules.optimize-boot =
    {
      config,
      ...
    }:
    let
      cfg = config.settings.optimize-boot;
    in
    {
      options.settings.optimize-boot = {
        enable = lib.mkEnableOption "boot time optimizations";
      };

      config = lib.mkIf cfg.enable {
        # Blacklist unnecessary kernel modules for faster boot
        boot.blacklistedKernelModules = [
          "serial8250"
          "pcspkr" # PC speaker
          "i2c_piix4" # Often unnecessary on modern systems
        ];

        # Optimize initrd compression for faster decompression
        boot.initrd.compressorArgs = [
          "-3"
          "-T0"
        ];

        # Use systemd in initrd for parallel initialization
        boot.initrd.systemd.enable = true;

        # Disable verbose initrd for faster boot
        boot.initrd.verbose = false;

        # Reduce boot loader timeout
        boot.loader.timeout = lib.mkDefault 1;

        # Kernel parameters for faster boot
        boot.kernelParams = lib.mkAfter [
          "quiet" # Reduce console output
          "loglevel=3" # Reduce log verbosity (only show errors and warnings)
          "udev.log_level=3" # Reduce udev logging
        ];

        # Don't wait for network before starting multi-user.target
        # Services that need network will depend on network-online.target explicitly
        systemd.services.systemd-networkd-wait-online = {
          wantedBy = lib.mkForce [ ];
          requiredBy = lib.mkForce [ ];
        };

        # Disable unnecessary systemd services
        systemd.services = {
          # Speed up NetworkManager if not critical
          NetworkManager-wait-online.enable = false;
        };

        # Optimize systemd timeouts
        systemd.settings.Manager = {
          DefaultTimeoutStartSec = "20s";
          DefaultTimeoutStopSec = "10s";
        };

        # Reduce udev settle timeout
        boot.initrd.systemd.services.systemd-udev-settle.serviceConfig.TimeoutSec = "10s";

        # Skip serial device initialization if not needed
        services.udev.extraRules = ''
          # Skip slow serial device probing
          SUBSYSTEM=="tty", KERNEL=="ttyS[0-9]*", ENV{SYSTEMD_WANTS}="", ENV{SYSTEMD_USER_WANTS}=""
        '';

        # Optimize journal
        services.journald.extraConfig = ''
          SystemMaxUse=100M
          RuntimeMaxUse=50M
        '';

        # Disable Plymouth boot splash for faster boot
        boot.plymouth.enable = lib.mkDefault false;

        # Optimize systemd-tmpfiles to skip unnecessary checks
        systemd.tmpfiles.settings."10-optimize-boot" = {
          "/tmp".d = {
            mode = "1777";
            user = "root";
            group = "root";
            age = "10d";
          };
        };

        # Parallel filesystem checks
        boot.initrd.checkJournalingFS = false;

        # Reduce initrd included modules to minimum
        boot.initrd.includeDefaultModules = lib.mkDefault true;

        # Speed up random number generation
        boot.kernel.sysctl = {
          "kernel.random.write_wakeup_threshold" = 128;
          "kernel.random.urandom_min_reseed_secs" = 60;
        };
      };
    };
}

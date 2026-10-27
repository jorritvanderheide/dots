{
  inputs,
  ...
}:
{
  # The Brother QL-700 that prints MeetINN's name labels at the door
  # (meetinn's README, "Name labels"). The check-in screen prints with
  # window.print(), which only Chromium with --kiosk-printing sends to the
  # default printer without a dialog for one window. Zen's way
  # (print.always_print_silent) would print everything that way.
  flake.nixosModules.label-printer =
    {
      lib,
      pkgs,
      ...
    }:
    let
      inherit (inputs.self.lib) site;
      printer = "QL-700";

      # Opens a meetinn-labels: link's address (the door page's link to the
      # check-in screen), or the admin without one. Only the demo's pages or
      # a dev server's on this machine: any site can link to
      # meetinn-labels:, and a page in this Chromium prints without asking.
      labels = pkgs.writeShellScript "meetinn-labels" ''
        url=''${1#meetinn-labels:}
        url=''${url:-https://inn.${site.domain}/admin}
        pattern='^(https://${lib.escapeRegex "inn.${site.domain}"}|http://localhost:[0-9]+)/'
        if ! [[ $url =~ $pattern ]]; then
          echo "meetinn-labels: not a MeetINN page: $url" >&2
          exit 1
        fi
        exec ${lib.getExe pkgs.chromium} --kiosk-printing \
          --user-data-dir="$HOME/.local/share/meetinn-labels" \
          --app="$url"
      '';
    in
    {
      config = {
        hardware.printers = {
          ensureDefaultPrinter = printer;

          # 62 mm continuous tape (DK-22205), cut after every label: the
          # label page's pages are 100 mm long.
          ensurePrinters = [
            {
              deviceUri = "usb://Brother/QL-700?serial=000J3Z539575";
              model = "ptouch-driver/Brother-QL-700-ptouch-ql.ppd.gz";
              name = printer;

              ppdOptions = {
                AutoCut = "True";
                CutLabel = "1";
                MediaType = "Tape";
                PageSize = "62x100mm";
              };
            }
          ];
        };

        # The profile is not preserved: after a reboot, log in with Yivi
        # again.
        home-manager.sharedModules = [
          {
            xdg.mimeApps.defaultApplications."x-scheme-handler/meetinn-labels" = "meetinn-labels.desktop";

            xdg.desktopEntries.meetinn-labels = {
              comment = "Prints a name label for every check-in";
              exec = "${labels} %u";
              icon = "printer";
              mimeType = [ "x-scheme-handler/meetinn-labels" ];
              name = "MeetINN labels";
              type = "Application";
            };
          }
        ];

        services.printing = {
          enable = true;
          drivers = [ pkgs.ptouch-driver ];

          # Only this printer: none from the network added by themselves.
          browsed.enable = false;
        };
      };
    };
}

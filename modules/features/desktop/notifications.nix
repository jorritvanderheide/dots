_: {
  flake.nixosModules.notifications =
    { pkgs, ... }:
    {
      config = {
        environment.systemPackages = [
          # `notify-send` for scripts and debugging, regardless of which
          # daemon (Weinig, here) receives it.
          pkgs.libnotify

          # nm-connection-editor, for NetworkManager's connection profiles
          # (e.g. ad-hoc Wi-Fi not declared in wifi/default.nix). Only the
          # editor, as the package also autostarts nm-applet, and Weinig asks
          # for Wi-Fi passwords itself.
          (pkgs.runCommand "nm-connection-editor" { } ''
            mkdir -p $out/bin $out/share/applications
            ln -s ${pkgs.networkmanagerapplet}/bin/nm-connection-editor $out/bin/
            ln -s ${pkgs.networkmanagerapplet}/share/applications/nm-connection-editor.desktop $out/share/applications/
          '')
        ];
      };
    };
}

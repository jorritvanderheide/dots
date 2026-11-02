{
  inputs,
  lib,
  ...
}:
{
  # Trying Weinig: it takes the frame, the bar, the launcher, notifications and the wallpaper.
  # noctalia keeps the rest until Weinig has it, from the lock screen to the clipboard. Dropping
  # this module brings noctalia's bar and wallpaper back.
  flake.nixosModules.weinig = {
    home-manager.sharedModules = [
      inputs.weinig-shell.homeModules.default
      (
        { config, pkgs, ... }:
        let
          inherit (config.lib.niri.actions) spawn;

          # In the background, so that the shell can't hold up an agent, and whether it is
          # running or not.
          agentHook =
            matcher: state:
            let
              script = pkgs.writeShellScript "weinig-agent" ''
                id=$(${lib.getExe pkgs.jq} -r .session_id)
                if [ "$1" = clear ]; then
                  exec ${lib.getExe config.programs.weinig.package} msg agent clear "$id"
                fi
                exec ${lib.getExe config.programs.weinig.package} msg agent set "$id" "$1"
              '';
            in
            {
              inherit matcher;

              hooks = [
                {
                  async = true;
                  command = "${script} ${state}";
                  type = "command";
                }
              ];
            };
        in
        {
          programs = {
            # An LED for each session in the bar. An interrupted turn has no Stop, so going
            # idle counts as done as well, which is also what ends a denied permission's red.
            claude-code.settings.hooks = {
              PostToolUse = [ (agentHook "" "working") ];
              PreToolUse = [ (agentHook "AskUserQuestion|ExitPlanMode" "waiting") ];
              SessionEnd = [ (agentHook "" "clear") ];
              Stop = [ (agentHook "" "done") ];
              UserPromptSubmit = [ (agentHook "" "working") ];

              Notification = [
                (agentHook "permission_prompt" "waiting")
                (agentHook "idle_prompt" "done")
              ];

              # Not on compact, which happens in the middle of a turn.
              SessionStart = [ (agentHook "startup|resume|clear|fork" "done") ];
            };

            niri.settings = {
              binds = {
                "Mod+M".action = lib.mkForce (spawn "weinig" "msg" "volume" "mute");
                "Mod+Shift+W".action = lib.mkForce (spawn "weinig" "msg" "wallpaper" "previous");
                "Mod+Space".action = lib.mkForce (spawn "weinig" "msg" "launcher" "toggle");
                "Mod+W".action = lib.mkForce (spawn "weinig" "msg" "wallpaper" "next");
                "XF86AudioLowerVolume".action = lib.mkForce (spawn "weinig" "msg" "volume" "down");
                "XF86AudioMute".action = lib.mkForce (spawn "weinig" "msg" "volume" "mute");
                "XF86AudioRaiseVolume".action = lib.mkForce (spawn "weinig" "msg" "volume" "up");
                "XF86MonBrightnessDown".action = lib.mkForce (spawn "weinig" "msg" "brightness" "down");
                "XF86MonBrightnessUp".action = lib.mkForce (spawn "weinig" "msg" "brightness" "up");

                # The bar's status isn't there yet, so noctalia's panel has to do.
                "Mod+N".action = spawn "noctalia" "msg" "panel-toggle" "control-center";
              };

              # One wallpaper behind the workspaces in the overview, as with noctalia's
              # backdrop (compositor.nix).
              layer-rules = [
                {
                  place-within-backdrop = true;

                  matches = [
                    { namespace = "^weinig-wallpaper$"; }
                  ];
                }
              ];
            };

            noctalia.settings = {
              backdrop.enabled = lib.mkForce false;
              bar.main.enabled = false;
              notification.enable_daemon = false;
              osd.enabled = false;
              shell.screen_corners.enabled = lib.mkForce false;
              wallpaper.enabled = lib.mkForce false;
            };

            weinig = {
              enable = true;

              settings = {
                primaryOutput = "eDP-1";

                launcher = {
                  launchCommand = [
                    "app2unit"
                    "-s"
                    "a"
                    "--"
                    "$CMD"
                  ];

                  terminal = [
                    "ghostty"
                    "-e"
                  ];
                };

                # The folder itself rather than a copy in the store, so that images added to
                # it show up without a rebuild.
                wallpaper.directory = "${config.home.homeDirectory}/Pictures/Wallpapers";
              };
            };
          };
        }
      )
    ];
  };
}

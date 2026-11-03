{
  inputs,
  lib,
  ...
}:
{
  # Trying Weinig: it takes the frame, the bar, the launcher, notifications, the wallpaper, the lock
  # screen and idle.
  # noctalia keeps the rest until Weinig has it, like the calendar. Dropping
  # this module brings noctalia's bar, wallpaper and lock screen back.
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
                input=$(cat)
                id=$(${lib.getExe pkgs.jq} -r .session_id <<<"$input")
                folder=$(${lib.getExe pkgs.jq} -r '.cwd // ""' <<<"$input")
                if [ "$1" = clear ]; then
                  exec ${lib.getExe config.programs.weinig.package} msg agent clear "$id"
                fi

                # A turn that ends on a question is waiting for an answer, not only done.
                state=$1
                if [ "$state" = stop ]; then
                  state=done
                  last=$(${lib.getExe pkgs.jq} -r '.last_assistant_message // ""' <<<"$input")
                  if [[ $last =~ \?[[:space:]*_\`\)\"]*$ ]]; then
                    state=waiting
                  fi
                fi

                # The processes above this one, for the window the agent is in.
                pids=""
                pid=$PPID
                while [ "$pid" -gt 1 ] && [ -r "/proc/$pid/status" ]; do
                  pids="$pids $pid"
                  while read -r key value; do
                    if [ "$key" = PPid: ]; then
                      pid=$value
                      break
                    fi
                  done <"/proc/$pid/status"
                done

                exec ${lib.getExe config.programs.weinig.package} msg agent set "$id" "$state" "$pids" "$folder"
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
            claude-code.settings = {
              # An edge of the screen flashes towards the session's window. An interrupted turn has
              # no Stop, so going idle counts as done as well.
              hooks = {
                PostToolUse = [ (agentHook "" "working") ];
                PreToolUse = [ (agentHook "AskUserQuestion|ExitPlanMode" "waiting") ];
                SessionEnd = [ (agentHook "" "clear") ];
                Stop = [ (agentHook "" "stop") ];
                UserPromptSubmit = [ (agentHook "" "working") ];

                Notification = [
                  (agentHook "permission_prompt" "waiting")
                  (agentHook "idle_prompt" "done")
                ];
              };

              # Ghostty would show its own notification for what the edge flashes for.
              preferredNotifChannel = "notifications_disabled";
            };

            niri.settings = {
              binds = {
                "Mod+Ctrl+N".action = spawn "weinig" "msg" "notifications" "toggle";
                "Mod+M".action = lib.mkForce (spawn "weinig" "msg" "volume" "mute");
                "Mod+N".action = spawn "weinig" "msg" "notifications" "toggleMute";
                "Mod+O".action = lib.mkForce (spawn "weinig" "msg" "colour" "pick");
                "Mod+P".action = lib.mkForce (spawn "niri" "msg" "action" "screenshot");
                "Mod+Shift+W".action = lib.mkForce (spawn "weinig" "msg" "wallpaper" "previous");
                "Mod+Space".action = lib.mkForce (spawn "weinig" "msg" "launcher" "toggle");
                "Mod+V".action = lib.mkForce (spawn "weinig" "msg" "clipboard" "toggle");
                "Mod+W".action = lib.mkForce (spawn "weinig" "msg" "wallpaper" "next");
                "XF86AudioLowerVolume".action = lib.mkForce (spawn "weinig" "msg" "volume" "down");
                "XF86AudioMute".action = lib.mkForce (spawn "weinig" "msg" "volume" "mute");
                "XF86AudioRaiseVolume".action = lib.mkForce (spawn "weinig" "msg" "volume" "up");
                "XF86MonBrightnessDown".action = lib.mkForce (spawn "weinig" "msg" "brightness" "down");
                "XF86MonBrightnessUp".action = lib.mkForce (spawn "weinig" "msg" "brightness" "up");

                # The bar's status isn't there yet, so noctalia's panel has to do.
                "Mod+Shift+N".action = spawn "noctalia" "msg" "panel-toggle" "control-center";
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

              # The session logs in by itself, so this is what asks for the password. First, and
              # if it can't lock, the session ends and the console asks instead.
              spawn-at-startup = lib.mkBefore [
                {
                  command = [
                    (lib.getExe config.programs.weinig.package)
                    "lock-start"
                  ];
                }
              ];
            };

            noctalia.settings = {
              backdrop.enabled = lib.mkForce false;
              bar.main.enabled = false;
              battery.warning_threshold = 0;
              lockscreen.enabled = lib.mkForce false;
              notification.enable_daemon = false;
              osd.enabled = false;
              shell.clipboard_enabled = false;
              shell.polkit_agent = lib.mkForce false;
              shell.screen_corners.enabled = lib.mkForce false;
              wallpaper.enabled = lib.mkForce false;

              # noctalia draws its own notifications even without its daemon, and the indicator
              # already shows headphones connecting and disconnecting.
              bluetooth.connection_notifications = false;

              # Weinig locks and goes idle (programs.weinig.idle).
              idle.behavior = {
                lock-and-suspend.enabled = lib.mkForce false;
                lock.enabled = lib.mkForce false;
                screen-off.enabled = lib.mkForce false;
              };
            };

            weinig = {
              enable = true;

              # Suspend, but not while a Claude Code turn is in progress (busy markers written by
              # the hooks in coding-agent.nix). As a transient unit, so that returning can cancel
              # the wait.
              idle = {
                suspendResumeCommand = "${pkgs.systemd}/bin/systemctl --user stop idle-suspend";

                suspendCommand = "${pkgs.systemd}/bin/systemd-run --user --collect --unit=idle-suspend ${pkgs.writeShellScript "idle-suspend" ''
                  dir="''${XDG_RUNTIME_DIR:-/run/user/$(id -u)}/claude-busy"
                  # Markers untouched for an hour are leftovers from an interrupted or crashed
                  # session, not real work.
                  while [ -n "$(${pkgs.findutils}/bin/find "$dir" -type f -mmin -60 2>/dev/null)" ]; do
                    sleep 60
                  done
                  ${pkgs.systemd}/bin/systemctl suspend
                ''}";
              };

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

    # Instead of noctalia locking when it can, Weinig locks first, or ends the session.
    my.desktop-shell.lockOnStartup = lib.mkForce false;
  };
}

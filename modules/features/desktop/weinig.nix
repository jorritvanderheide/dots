{
  inputs,
  lib,
  ...
}:
{
  # Weinig is the desktop's shell, from the frame to the lock screen.
  flake.nixosModules.weinig =
    { config, pkgs, ... }:
    {
      imports = [ inputs.weinig-shell.nixosModules.default ];

      home-manager.sharedModules = [
        (
          { pkgs, ... }:
          let

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
                # One wallpaper behind the workspaces in the overview, which let it through
                # (compositor.nix).
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

            };
          }
        )
      ];

      programs.weinig = {
        enable = true;

        # niri-stack (keybinds.nix) makes them one list over the monitors.
        bar.workspaces = "all";

        # Ghostty, below.
        desktop.terminal = false;

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

        # This Framework's hardware switches, open or not.
        inUse.switches = true;

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

        # This config has its own keys and rules.
        niri.enable = false;

        # The monitors at a desk, and not those of a meeting room, which show what I share.
        primaryOutput = [
          "LG HDR 4K"
          "eDP-1"
        ];

        # The folder itself rather than a copy in the store, so that images added to
        # it show up without a rebuild.
        wallpaper.directory = "${
          config.users.users.${config.my.session.autologinuser}.home
        }/Pictures/Wallpapers";
      };
    };
}

{
  flake.nixosModules.keybinds = {
    config = {
      home-manager.sharedModules = [
        (
          {
            config,
            lib,
            pkgs,
            ...
          }:
          let
            # One list of workspaces, with the monitors as a window over it: the external shows
            # one and the laptop the next. niri keeps workspaces per monitor, so the external
            # holds the list up to its window and the laptop the rest, showing its first.
            # Sliding moves one workspace across. They are named, as only names reach the other
            # monitor, and not numbers, as niri reads those as an index.
            stackPackage = pkgs.writeShellApplication {
              name = "niri-stack";

              runtimeInputs = [
                config.programs.niri.package
                pkgs.jq
                pkgs.util-linux
              ];

              text = ''
                laptop=eDP-1

                read_state() {
                  state=$(niri msg --json workspaces)
                  {
                    read -r external
                    read -ra list
                    read -ra upper
                    read -ra lower
                  } < <(jq -r --arg laptop "$laptop" '
                    def named($output): map(select(.name and .output == $output) | .name) | sort | join(" ");
                    (if any(.[]; .output == $laptop) then [.[].output | select(. != $laptop)][0] // "" else "" end) as $external
                    | $external, (map(.name // empty) | sort | join(" ")), named($external), named($laptop)
                  ' <<<"$state")
                }

                # The workspace this many places from the focused one in the list, if any.
                neighbour() {
                  focused=$(jq -r '.[] | select(.is_focused) | .name // empty' <<<"$state")
                  for i in "''${!list[@]}"; do
                    j=$((i + $1))
                    if [ "''${list[i]}" = "$focused" ] && [ "$j" -ge 0 ] && [ "$j" -lt "''${#list[@]}" ]; then
                      echo "''${list[j]}"
                    fi
                  done
                }

                order() {
                  i=1
                  for ws in "$@"; do
                    niri msg action move-workspace-to-index --reference "$ws" "$i"
                    i=$((i + 1))
                  done
                }

                # Whether no window is on this workspace or any after it, which makes it the end
                # of the list: the first empty one after the last window.
                ends_here() {
                  jq -e --argjson windows "$windows" --arg from "$1" 'any(.[]; .name and .name >= $from and (.id as $id | any($windows[]; .workspace_id == $id))) | not' <<<"$state" >/dev/null
                }

                # Whether no window is on this workspace or any before it, which makes it the top
                # of the list: the first empty one before the first window.
                starts_here() {
                  jq -e --argjson windows "$windows" --arg to "$1" 'any(.[]; .name and .name <= $to and (.id as $id | any($windows[]; .workspace_id == $id))) | not' <<<"$state" >/dev/null
                }

                occupied() {
                  jq -e --argjson windows "$(niri msg --json windows)" --arg ws "$1" 'any(.[]; .name == $ws and (.id as $id | any($windows[]; .workspace_id == $id)))' <<<"$state" >/dev/null
                }

                # Keeps an empty workspace above the first window. Once one reaches the first
                # workspace, every name moves one down the list, which brings the empty last
                # workspace to the top. No window or screen changes for it.
                make_room() {
                  if occupied "''${list[0]}" && ! occupied "''${list[-1]}"; then
                    niri msg action set-workspace-name --workspace "''${list[-1]}" shifting
                    for ((i = ''${#list[@]} - 1; i > 0; i--)); do
                      niri msg action set-workspace-name --workspace "''${list[i - 1]}" "''${list[i]}"
                    done
                    niri msg action set-workspace-name --workspace shifting "''${list[0]}"
                    read_state
                  fi
                }

                # Down moves what is shown down the screens, so to earlier in the list. The
                # focused workspace keeps the focus if it stays visible.
                slide() {
                  if [ -z "$external" ]; then
                    focused=$(jq -r '.[] | select(.is_focused) | .name // empty' <<<"$state")
                    if [ "$1" = up ] && ends_here "$focused"; then return; fi
                    if [ "$1" = down ] && starts_here "$focused"; then return; fi
                    if [ "$1" = down ]; then ws=$(neighbour -1); else ws=$(neighbour 1); fi
                  elif [ "$1" = down ]; then
                    if [ "''${#upper[@]}" -lt 2 ] || starts_here "''${upper[-1]}"; then return; fi
                    ws=''${upper[-1]}
                    niri msg action move-workspace-to-monitor --reference "$ws" "$laptop"
                    niri msg action move-workspace-to-index --reference "$ws" 1
                  else
                    if [ "''${#lower[@]}" -lt 2 ] || ends_here "''${lower[0]}"; then return; fi
                    ws=''${lower[0]}
                    niri msg action move-workspace-to-monitor --reference "$ws" "$external"
                    niri msg action move-workspace-to-index --reference "$ws" "$((''${#upper[@]} + 1))"
                  fi
                  if [ -n "$ws" ]; then niri msg action focus-workspace "$ws"; fi
                }

                # Moves the focused window along the list, sliding along if it would leave the screens.
                window() {
                  if [ "$1" = down ]; then target=$(neighbour 1) away=up; else target=$(neighbour -1) away=down; fi
                  if [ -z "$target" ]; then return; fi
                  if [ -n "$external" ] && [ "$(jq --arg ws "$target" '.[] | select(.name == $ws) | .is_active' <<<"$state")" = false ]; then
                    slide "$away"
                  fi
                  niri msg action move-window-to-workspace "$target"
                }

                # Windows on a workspace outside the list go to an empty one in it, preferably
                # the one their monitor is to show.
                adopt() {
                  windows=$(niri msg --json windows)
                  mapfile -t stray < <(jq -r --argjson windows "$windows" '.[] | select(.name == null and (.id as $id | any($windows[]; .workspace_id == $id))) | "\(.id) \(.output)"' <<<"$state")
                  mapfile -t taken < <(jq -r --argjson windows "$windows" '.[] | select(.name and (.id as $id | any($windows[]; .workspace_id == $id))) | .name' <<<"$state")
                  for entry in "''${stray[@]}"; do
                    read -r id output <<<"$entry"
                    shown=""
                    if [ "$output" = "$laptop" ] && [ "''${#lower[@]}" -gt 0 ]; then shown=''${lower[0]}; fi
                    if [ "$output" != "$laptop" ] && [ "''${#upper[@]}" -gt 0 ]; then shown=''${upper[-1]}; fi
                    target=""
                    for ws in "$shown" "''${list[@]}"; do
                      case " ''${taken[*]} " in
                        *" $ws "*) ;;
                        *)
                          if [ -n "$ws" ]; then
                            target=$ws
                            break
                          fi
                          ;;
                      esac
                    done
                    if [ -z "$target" ]; then continue; fi
                    taken+=("$target")
                    jq -r --argjson id "$id" 'map(select(.workspace_id == $id)) | sort_by(.layout.pos_in_scrolling_layout) | .[].id' <<<"$windows" |
                      while read -r window; do
                        niri msg action move-window-to-workspace --window-id "$window" --focus false "$target"
                      done
                  done
                }

                sort_monitor() {
                  if ! jq -e --arg output "$1" 'map(select(.name and .output == $output)) | sort_by(.idx) | map(.name) | . == sort' <<<"$state" >/dev/null; then
                    shift
                    order "$@"
                  fi
                }

                # Puts everything back in place: the list split over the monitors, every window
                # on it, and the screens showing the two workspaces at the split.
                place() {
                  make_room
                  if [ -z "$external" ]; then
                    adopt
                    sort_monitor "$laptop" "''${list[@]}"
                    read_state
                    return
                  fi
                  if [ "''${#upper[@]}" -eq 0 ]; then
                    niri msg action move-workspace-to-monitor --reference "''${list[0]}" "$external"
                  elif [ "''${#lower[@]}" -eq 0 ]; then
                    niri msg action move-workspace-to-monitor --reference "''${list[-1]}" "$laptop"
                  fi
                  read_state
                  for ws in "''${lower[@]}"; do
                    if [[ $ws < "''${upper[-1]}" ]]; then
                      niri msg action move-workspace-to-monitor --reference "$ws" "$external"
                    fi
                  done
                  read_state
                  adopt
                  sort_monitor "$external" "''${upper[@]}"
                  sort_monitor "$laptop" "''${lower[@]}"
                  if ! jq -e --arg upper "''${upper[-1]}" --arg lower "''${lower[0]}" 'map(select(.is_active) | .name) | contains([$upper, $lower])' <<<"$state" >/dev/null; then
                    focused=$(jq -r '.[] | select(.is_focused) | .output' <<<"$state")
                    niri msg action focus-workspace "''${lower[0]}"
                    niri msg action focus-workspace "''${upper[-1]}"
                    if [ "$focused" = "$laptop" ]; then niri msg action focus-monitor "$laptop"; fi
                  fi
                  read_state
                }

                # Puts every other screen centred above the laptop, each above the one before, as
                # niri's config can't say that for a screen it doesn't know by name.
                place_outputs() {
                  niri msg --json outputs | jq -r --arg laptop "$laptop" '
                    .[$laptop].logical as $base
                    | select($base)
                    | to_entries
                    | map(select(.key != $laptop and .value.logical))
                    | sort_by(.key) as $others
                    | foreach $others[] as $other ($base.y;
                        . - $other.value.logical.height;
                        {
                          name: $other.key,
                          x: ($base.x + ($base.width - $other.value.logical.width) / 2 | floor),
                          y: .,
                          at: $other.value.logical
                        })
                    | select(.x != .at.x or .y != .at.y)
                    | "\(.name) \(.x) \(.y)"
                  ' | while read -r name x y; do
                    niri msg output "$name" position set -- "$x" "$y"
                  done
                }

                # Shows the workspace with this id again, for when its monitor is gone.
                refocus() {
                  name=$(niri msg --json workspaces | jq -r --argjson id "$1" '.[] | select(.id == $id) | .name // empty')
                  if [ -n "$name" ]; then niri msg action focus-workspace "$name"; fi
                }

                # One at a time, in the order of the presses: each acts on the state it read, over
                # several actions, and a second one in between can split the list wrongly.
                settle() {
                  exec 9>"$XDG_RUNTIME_DIR/niri-stack.lock"
                  flock 9
                  read_state
                  windows=$(niri msg --json windows)
                  if ! in_place; then
                    if [ "''${1:-}" = follow ]; then follow; fi
                    place
                    windows=$(niri msg --json windows)
                  fi
                }

                # Moves the split to a workspace something else made current, such as a click on
                # it in the bar or the overview, for place to then show it rather than undo it.
                follow() {
                  if [ -z "$external" ] || [ "''${#upper[@]}" -eq 0 ] || [ "''${#lower[@]}" -eq 0 ]; then return; fi
                  shown_upper=$(jq -r --arg output "$external" '.[] | select(.output == $output and .is_active) | .name // empty' <<<"$state")
                  shown_lower=$(jq -r --arg output "$laptop" '.[] | select(.output == $output and .is_active) | .name // empty' <<<"$state")
                  if [ -n "$shown_upper" ] && [ "$shown_upper" != "''${upper[-1]}" ]; then
                    for ((i = ''${#upper[@]} - 1; i >= 0; i--)); do
                      if [ "''${upper[i]}" = "$shown_upper" ]; then break; fi
                      niri msg action move-workspace-to-monitor --reference "''${upper[i]}" "$laptop"
                    done
                  elif [ -n "$shown_lower" ] && [ "$shown_lower" != "''${lower[0]}" ]; then
                    for ws in "''${lower[@]}"; do
                      if [ "$ws" = "$shown_lower" ]; then break; fi
                      niri msg action move-workspace-to-monitor --reference "$ws" "$external"
                    done
                  fi
                  read_state
                }

                # Whether place would change nothing, in one go as it nearly always would not.
                in_place() {
                  jq -e --argjson windows "$windows" --arg laptop "$laptop" --arg external "$external" '
                    [$windows[].workspace_id] as $busy
                    | map(. + {busy: (.id as $id | $busy | index($id) != null)}) as $all
                    | ($all | map(select(.name)) | sort_by(.name)) as $list
                    | ($list | map(select(.output == $external))) as $upper
                    | ($list | map(select(.output == $laptop))) as $lower
                    | (any($all[]; .name == null and .busy) | not)
                    and (($list[0].busy | not) or $list[-1].busy)
                    and all(($upper, $lower); map(.idx) == (map(.idx) | sort))
                    and ($external == "" or (
                      ($upper | length) > 0 and ($lower | length) > 0
                      and $upper[-1].name < $lower[0].name
                      and $upper[-1].is_active and $lower[0].is_active
                    ))
                  ' <<<"$state" >/dev/null
                }

                case "$1" in
                  focus)
                    read_state
                    if [ -n "$external" ]; then
                      niri msg action "focus-window-or-monitor-$2"
                    else
                      niri msg action "focus-window-or-workspace-$2"
                    fi
                    ;;
                  slide)
                    settle
                    slide "$2"
                    ;;
                  window)
                    settle
                    window "$2"
                    ;;
                  watch)
                    last="" focused="" screens=0
                    niri msg --json event-stream |
                      jq --unbuffered -r '
                        if .WorkspaceActivated then
                          "activated \(if .WorkspaceActivated.focused then .WorkspaceActivated.id else "" end)"
                        else
                          .WorkspacesChanged.workspaces // empty
                          | "\(map(.output) | unique | length) \(map(.name // empty) | length) \(map(select(.is_focused) | .id)[0] // "")"
                        end
                      ' |
                      while read -r first second third; do
                        if [ "$first" = activated ]; then
                          if [ -n "$second" ]; then focused=$second; fi
                          (settle follow)
                          continue
                        fi

                        layout="$first $second"
                        if [ "$layout" != "$last" ]; then
                          last=$layout
                          place_outputs
                          (settle)
                          # By now niri has moved the focus, so this is the one from before.
                          if [ "$first" -lt "$screens" ] && [ -n "$focused" ]; then refocus "$focused"; fi
                          screens=$first
                        fi
                        focused=$third
                      done
                    ;;
                esac
              '';
            };
            stack = lib.getExe stackPackage;
          in
          {
            home.packages = [ stackPackage ];

            # A slide changes the size of every window on the workspace it moves, as the monitors
            # differ, and this would animate over that. Nothing else uses it any more.
            programs.niri.settings.animations.workspace-switch.enable = false;

            programs.niri.settings.binds = with config.lib.niri.actions; {
              "Alt+Tab" = {
                action = spawn "true";
                repeat = false;
              };

              "Mod+Alt+Ctrl+Down" = {
                action = spawn stack "window" "down";
                repeat = false;
              };

              "Mod+Alt+Ctrl+H" = {
                action = move-window-to-monitor-left;
                repeat = false;
              };

              "Mod+Alt+Ctrl+J" = {
                action = spawn stack "window" "down";
                repeat = false;
              };

              "Mod+Alt+Ctrl+K" = {
                action = spawn stack "window" "up";
                repeat = false;
              };

              "Mod+Alt+Ctrl+L" = {
                action = move-window-to-monitor-right;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Left" = {
                action = move-window-to-monitor-left;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Right" = {
                action = move-window-to-monitor-right;
                repeat = false;
              };

              "Mod+Alt+Ctrl+Up" = {
                action = spawn stack "window" "up";
                repeat = false;
              };

              "Mod+Alt+Down" = {
                action = spawn stack "slide" "down";
                repeat = false;
              };

              "Mod+Alt+F" = {
                action = toggle-windowed-fullscreen;
                repeat = false;
              };

              "Mod+Alt+H" = {
                action = move-column-left;
                repeat = false;
              };

              "Mod+Alt+J" = {
                action = spawn stack "slide" "down";
                repeat = false;
              };

              "Mod+Alt+K" = {
                action = spawn stack "slide" "up";
                repeat = false;
              };

              "Mod+Alt+L" = {
                action = move-column-right;
                repeat = false;
              };

              "Mod+Alt+Left" = {
                action = move-column-left;
                repeat = false;
              };

              "Mod+Alt+Right" = {
                action = move-column-right;
                repeat = false;
              };

              "Mod+Alt+Up" = {
                action = spawn stack "slide" "up";
                repeat = false;
              };

              "Mod+Backspace" = {
                action = spawn "weinig" "lock-session";
                repeat = false;
              };

              "Mod+Ctrl+Down" = {
                action = focus-monitor-down;
                repeat = false;
              };

              "Mod+Ctrl+H" = {
                action = focus-monitor-left;
                repeat = false;
              };

              "Mod+Ctrl+J" = {
                action = focus-monitor-down;
                repeat = false;
              };

              "Mod+Ctrl+K" = {
                action = focus-monitor-up;
                repeat = false;
              };

              "Mod+Ctrl+L" = {
                action = focus-monitor-right;
                repeat = false;
              };

              "Mod+Ctrl+Left" = {
                action = focus-monitor-left;
                repeat = false;
              };

              "Mod+Ctrl+N" = {
                action = spawn "weinig" "msg" "notifications" "toggle";
                repeat = false;
              };

              "Mod+Ctrl+Right" = {
                action = focus-monitor-right;
                repeat = false;
              };

              "Mod+Ctrl+Up" = {
                action = focus-monitor-up;
                repeat = false;
              };

              "Mod+Down" = {
                action = spawn stack "focus" "down";
                repeat = false;
              };

              "Mod+Escape" = {
                action = toggle-overview;
                repeat = false;
              };

              "Mod+F" = {
                action = fullscreen-window;
                repeat = false;
              };

              "Mod+H" = {
                action = focus-column-or-monitor-left;
                repeat = false;
              };

              # On the right hand's home row, as Right Alt is AltGr in this layout: the left hand's
              # Mod and Alt mask T, which is on the same hand.
              "Mod+ISO_Level3_Shift+T" = {
                action = spawn "weinig" "msg" "theme" "toggle";
                repeat = false;
              };

              "Mod+J" = {
                action = spawn stack "focus" "down";
                repeat = false;
              };

              "Mod+K" = {
                action = spawn stack "focus" "up";
                repeat = false;
              };

              "Mod+L" = {
                action = focus-column-or-monitor-right;
                repeat = false;
              };

              "Mod+Left" = {
                action = focus-column-or-monitor-left;
                repeat = false;
              };

              "Mod+M" = {
                action = spawn "weinig" "msg" "volume" "mute";
                allow-when-locked = true;
                repeat = false;
              };

              "Mod+N" = {
                action = spawn "weinig" "msg" "notifications" "toggleMute";
                repeat = false;
              };

              "Mod+O" = {
                action = spawn "weinig" "msg" "colour" "pick";
                repeat = false;
              };

              "Mod+P" = {
                action = spawn "niri" "msg" "action" "screenshot";
                repeat = false;
              };

              "Mod+Q" = {
                action = close-window;
                repeat = false;
              };

              "Mod+R" = {
                action = switch-preset-column-width;
                repeat = false;
              };

              "Mod+Return" = {
                action = spawn "app2unit" "-s" "a" "--" "ghostty";
                repeat = false;
              };

              "Mod+Right" = {
                action = focus-column-or-monitor-right;
                repeat = false;
              };

              "Mod+Shift+N" = {
                action = spawn "weinig" "msg" "notifications" "toggle";
                repeat = false;
              };

              "Mod+Shift+W" = {
                action = spawn "weinig" "msg" "wallpaper" "previous";
                repeat = false;
              };

              "Mod+Space" = {
                action = spawn "weinig" "msg" "launcher" "toggle";
                repeat = false;
              };

              "Mod+Tab" = {
                action = spawn "false";
                repeat = false;
              };

              "Mod+Up" = {
                action = spawn stack "focus" "up";
                repeat = false;
              };

              "Mod+V" = {
                action = spawn "weinig" "msg" "clipboard" "toggle";
                repeat = false;
              };

              "Mod+W" = {
                action = spawn "weinig" "msg" "wallpaper" "next";
                repeat = false;
              };

              "XF86AudioLowerVolume" = {
                action = spawn "weinig" "msg" "volume" "down";
                allow-when-locked = true;
              };

              "XF86AudioMedia" = {
                action = spawn "app2unit" "-s" "a" "--" "zeditor" "--new" "/etc/nixos";
                repeat = false;
              };

              "XF86AudioMute" = {
                action = spawn "weinig" "msg" "volume" "mute";
                allow-when-locked = true;
                repeat = false;
              };

              "XF86AudioNext" = {
                action = spawn "playerctl" "next";
                allow-when-locked = true;
                repeat = false;
              };

              "XF86AudioPause" = {
                action = spawn "playerctl" "play-pause";
                allow-when-locked = true;
                repeat = false;
              };

              "XF86AudioPlay" = {
                action = spawn "playerctl" "play-pause";
                allow-when-locked = true;
                repeat = false;
              };

              "XF86AudioPrev" = {
                action = spawn "playerctl" "previous";
                allow-when-locked = true;
                repeat = false;
              };

              "XF86AudioRaiseVolume" = {
                action = spawn "weinig" "msg" "volume" "up";
                allow-when-locked = true;
              };

              "XF86MonBrightnessDown" = {
                action = spawn "weinig" "msg" "brightness" "down";
                allow-when-locked = true;
              };

              "XF86MonBrightnessUp" = {
                action = spawn "weinig" "msg" "brightness" "up";
                allow-when-locked = true;
              };
            };

            programs.niri.settings.workspaces = lib.genAttrs (map (n: "w${toString n}") (lib.range 1 9)) (_: {
              open-on-output = "eDP-1";
            });

            systemd.user.services.niri-stack = {
              Install.WantedBy = [ "graphical-session.target" ];

              Service = {
                ExecStart = "${stack} watch";
                RestartSec = 5;

                # The event stream ends when niri does.
                Restart = "always";
              };

              Unit = {
                After = [ "graphical-session.target" ];
                Description = "Keep niri's workspaces one list across the monitors";
                PartOf = [ "graphical-session.target" ];
              };
            };
          }
        )
      ];
    };
  };
}

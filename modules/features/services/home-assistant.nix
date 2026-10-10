{
  inputs,
  lib,
  ...
}:
{
  flake.nixosModules.home-assistant =
    {
      config,
      pkgs,
      ...
    }:
    let
      cfg = config.my.home-assistant;
      subdomain = "home";
      port = 8123;

      hass-py = pkgs.home-assistant.python3Packages;
      enphase-envoy-installer = pkgs.buildHomeAssistantComponent rec {
        owner = "vincentwolsink";
        domain = "enphase_envoy";
        version = "0.8.4";
        src = pkgs.fetchFromGitHub {
          owner = "vincentwolsink";
          repo = "home_assistant_enphase_envoy_installer";
          tag = version;
          hash = "sha256-IHnJCtrAFhLoyyfgruvCIFFrtUTpTnebKWZcJA3ruog=";
        };
        dependencies = with hass-py; [
          pyjwt
          xmltodict
          httpx
          jsonpath
        ];
      };
    in
    {
      options.my.home-assistant = {
        enable = lib.mkEnableOption "Home Assistant smart home server";

        lanAccess = {
          enable = lib.mkEnableOption "plain-HTTP access from the home LAN, for devices with no Tailscale client";

          interface = lib.mkOption {
            type = lib.types.str;
            default = "enp2s0";
            description = "LAN interface to open the Home Assistant port on.";
          };
        };
      };

      config = lib.mkIf cfg.enable (
        lib.mkMerge [
          (inputs.self.lib.mkReverseProxy {
            inherit config port;
            inherit subdomain;
          })
          {
            services.home-assistant = {
              enable = true;
              extraComponents = [
                "default_config"
                "esphome"
                "reolink"
                "zha"
              ];
              customComponents = [
                enphase-envoy-installer
                pkgs.home-assistant-custom-components.localtuya
              ];

              config = {
                default_config = { };
                homeassistant = {
                  latitude = 51.8425;
                  longitude = 5.8528;
                  elevation = 19;
                  unit_system = "metric";
                  time_zone = config.time.timeZone;
                };
                http = {
                  # Loopback is enough for the tailnet vhost, which proxies
                  # from 127.0.0.1. LAN access needs a real listener, and the
                  # firewall below is what keeps it to the LAN interface.
                  server_host = if cfg.lanAccess.enable then "0.0.0.0" else "127.0.0.1";
                  server_port = port;
                  use_x_forwarded_for = true;
                  trusted_proxies = [ "127.0.0.1" ];
                };

                # Automations made in the UI live in automations.yaml, next
                # to the declared ones below.
                "automation ui" = "!include automations.yaml";
                # The ventilators are master/slave pairs (kitchen + office,
                # bedroom + bathroom): a master's mode and "powerful" boost
                # carry over to its slave. "ventilate" is the normal
                # heat-recovery mode; a boost switches the pair to exhaust.
                "automation manual" = [
                  {
                    id = "bathroom_shower_boost_on";
                    alias = "Bathroom: boost ventilation on shower";
                    # Relative to the baseline: the bathroom's normal humidity
                    # shifts with the seasons (around 70% in summer).
                    triggers = [
                      {
                        trigger = "template";
                        value_template = ''
                          {{ states('sensor.temperatuur_sensor_humidity') | float(0)
                             >= states('sensor.bathroom_humidity_baseline') | float(100) + 10 }}
                        '';
                      }
                    ];
                    actions = [
                      {
                        action = "select.select_option";
                        target.entity_id = "select.bedroom_mode";
                        data.option = "exhaust";
                      }
                      {
                        action = "switch.turn_on";
                        target.entity_id = "switch.bedroom_ventilator_powerful";
                      }
                    ];
                  }
                  {
                    id = "bathroom_shower_boost_off";
                    alias = "Bathroom: end shower boost";
                    triggers = [
                      {
                        trigger = "template";
                        value_template = ''
                          {{ states('sensor.temperatuur_sensor_humidity') | float(0)
                             <= states('sensor.bathroom_humidity_baseline') | float(0) + 3 }}
                        '';
                        for.minutes = 5;
                      }
                      # Cap, in case humidity never settles back down.
                      {
                        trigger = "state";
                        entity_id = "switch.bedroom_ventilator_powerful";
                        to = "on";
                        for.minutes = 45;
                      }
                    ];
                    actions = [
                      {
                        action = "switch.turn_off";
                        target.entity_id = "switch.bedroom_ventilator_powerful";
                      }
                      {
                        action = "select.select_option";
                        target.entity_id = "select.bedroom_mode";
                        data.option = "ventilate";
                      }
                    ];
                  }
                  {
                    id = "kitchen_cooking_boost";
                    alias = "Kitchen: cooking boost";
                    # The switch is the boost: turning it on starts it, turning
                    # it off (by hand, or itself after 30 minutes) ends it.
                    # Meanwhile the bedroom pair supplies, so the house stays
                    # balanced and fresh air sweeps from the bedrooms to the
                    # kitchen. It only touches the bedroom pair when that is in
                    # its normal mode, so a shower boost there wins.
                    mode = "restart";
                    triggers = [
                      {
                        trigger = "state";
                        entity_id = "input_boolean.cooking_boost";
                        from = "off";
                        to = "on";
                        id = "start";
                      }
                      {
                        trigger = "state";
                        entity_id = "input_boolean.cooking_boost";
                        from = "on";
                        to = "off";
                        id = "end";
                      }
                      # A restart loses the 30-minute delay, so end any boost
                      # that was running.
                      {
                        trigger = "homeassistant";
                        event = "start";
                        id = "startup";
                      }
                    ];
                    actions = [
                      {
                        choose = [
                          {
                            conditions = [
                              {
                                condition = "trigger";
                                id = "start";
                              }
                            ];
                            sequence = [
                              {
                                action = "select.select_option";
                                target.entity_id = "select.kitchen_mode";
                                data.option = "exhaust";
                              }
                              {
                                action = "switch.turn_on";
                                target.entity_id = "switch.living_room_ventilator_powerful";
                              }
                              {
                                "if" = [
                                  {
                                    condition = "state";
                                    entity_id = "select.bedroom_mode";
                                    state = "ventilate";
                                  }
                                ];
                                "then" = [
                                  {
                                    action = "select.select_option";
                                    target.entity_id = "select.bedroom_mode";
                                    data.option = "supply";
                                  }
                                ];
                              }
                              { delay.minutes = 30; }
                              {
                                action = "input_boolean.turn_off";
                                target.entity_id = "input_boolean.cooking_boost";
                              }
                            ];
                          }
                          {
                            conditions = [
                              {
                                condition = "trigger";
                                id = "end";
                              }
                            ];
                            sequence = [
                              {
                                action = "switch.turn_off";
                                target.entity_id = "switch.living_room_ventilator_powerful";
                              }
                              {
                                action = "select.select_option";
                                target.entity_id = "select.kitchen_mode";
                                data.option = "ventilate";
                              }
                              {
                                "if" = [
                                  {
                                    condition = "state";
                                    entity_id = "select.bedroom_mode";
                                    state = "supply";
                                  }
                                ];
                                "then" = [
                                  {
                                    action = "select.select_option";
                                    target.entity_id = "select.bedroom_mode";
                                    data.option = "ventilate";
                                  }
                                ];
                              }
                            ];
                          }
                          {
                            conditions = [
                              {
                                condition = "trigger";
                                id = "startup";
                              }
                            ];
                            sequence = [
                              {
                                action = "input_boolean.turn_off";
                                target.entity_id = "input_boolean.cooking_boost";
                              }
                            ];
                          }
                        ];
                      }
                    ];
                  }
                  {
                    id = "free_cooling";
                    alias = "Ventilation: free cooling";
                    # Indoor is the bathroom sensor, so a shower must not count
                    # as a warm house. A heated bathroom on a mild day looks the
                    # same as a summer evening, so it only runs May-September.
                    triggers = [
                      {
                        trigger = "template";
                        value_template = ''
                          {% set indoor = states('sensor.temperatuur_sensor_temperature') | float(0) %}
                          {% set outdoor = states('sensor.bedroom_current_temperature') | float(99) %}
                          {% set shower = states('sensor.temperatuur_sensor_humidity') | float(100)
                             >= states('sensor.bathroom_humidity_baseline') | float(0) + 5 %}
                          {{ now().month in [5, 6, 7, 8, 9]
                             and indoor > 24 and outdoor >= 12 and outdoor <= indoor - 2 and not shower }}
                        '';
                        for.minutes = 30;
                        id = "on";
                      }
                      {
                        trigger = "template";
                        value_template = ''
                          {% set indoor = states('sensor.temperatuur_sensor_temperature') | float(0) %}
                          {% set outdoor = states('sensor.bedroom_current_temperature') | float(0) %}
                          {{ now().month not in [5, 6, 7, 8, 9]
                             or indoor < 22 or outdoor >= indoor or outdoor < 10 }}
                        '';
                        for.minutes = 15;
                        id = "off";
                      }
                    ];
                    actions = [
                      {
                        "if" = [
                          {
                            condition = "trigger";
                            id = "on";
                          }
                        ];
                        "then" = [
                          {
                            action = "switch.turn_on";
                            target.entity_id = [
                              "switch.living_room_ventilator_free_cooling"
                              "switch.bedroom_ventilator_free_cooling"
                            ];
                          }
                        ];
                        "else" = [
                          {
                            action = "switch.turn_off";
                            target.entity_id = [
                              "switch.living_room_ventilator_free_cooling"
                              "switch.bedroom_ventilator_free_cooling"
                            ];
                          }
                        ];
                      }
                    ];
                  }
                ];
                # What "normal" bathroom humidity is right now, for spotting
                # showers. Time-weighted, so the quick sensor updates during a
                # shower don't drag it up.
                sensor = [
                  {
                    platform = "statistics";
                    name = "Bathroom humidity baseline";
                    unique_id = "bathroom_humidity_baseline";
                    entity_id = "sensor.temperatuur_sensor_humidity";
                    state_characteristic = "average_step";
                    max_age.hours = 3;
                    sampling_size = 1000;
                    keep_last_sample = true;
                  }
                ];
                input_boolean.cooking_boost = {
                  name = "Cooking boost";
                  icon = "mdi:fan-chevron-up";
                };
              };
            };

            systemd.services.home-assistant.serviceConfig.Restart = lib.mkForce "always";

            # The include above stops HA from starting if the file is
            # missing. "f" only creates it; existing content is left alone.
            systemd.tmpfiles.rules = [
              "f ${config.services.home-assistant.configDir}/automations.yaml 0644 hass hass - []"
            ];

            # ZHA: let HA open the Zigbee dongle's serial port.
            users.users.hass.extraGroups = [ "dialout" ];

            my.offsite-backup.entries.home-assistant.paths = [ "/var/lib/hass" ];

            my.preservation.systemDirectories = [
              {
                directory = "/var/lib/hass";
                user = "hass";
                group = "hass";
                mode = "0700";
              }
            ];
          }

          # Scoped to the LAN interface rather than opened globally, which
          # would also expose it on the path the router forwards 443 in on.
          # Plain HTTP: this is the bare port, not the TLS vhost, so LAN
          # traffic here is unencrypted.
          (lib.mkIf cfg.lanAccess.enable {
            networking.firewall.interfaces.${cfg.lanAccess.interface}.allowedTCPPorts = [ port ];
          })
        ]
      );
    };
}

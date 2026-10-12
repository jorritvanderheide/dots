# The house's own logic: the declared automations and the helpers they
# use. The service itself is in default.nix.
{
  flake.nixosModules.home-assistant =
    {
      config,
      lib,
      ...
    }:
    let
      # One ventilator pair to medium while its master reads high CO2, back to
      # low once it settles. The units' own anti-CO2 function would switch the
      # pair to supply instead, which loses heat recovery and has both units
      # blowing in; this keeps them in whatever mode they are in. With that
      # function off the unit ignores its CO2 target, so the target is reused
      # here: medium above target + 100, low again below the target. 800 if
      # it can't be read.
      co2Speed =
        {
          alias,
          fan,
          id,
          sensor,
          target,
        }:
        {
          inherit id alias;

          actions = [
            {
              action = "fan.set_percentage";

              # The speeds are low, medium, high: 33% is low and 66% medium,
              # whether or not LocalTuya's speed list also counts "off".
              data.percentage = "{{ 66 if trigger.id == 'high' else 33 }}";

              target.entity_id = fan;
            }
          ];

          # Setting a speed turns the unit on, so leave one switched off alone.
          conditions = [
            {
              condition = "state";
              entity_id = fan;
              state = "on";
            }
          ];

          triggers = [
            {
              for.minutes = 5;
              id = "high";
              trigger = "template";

              value_template = ''
                {{ states('${sensor}') | float(0)
                   > states('${target}') | float(800) + 100 }}
              '';
            }
            {
              for.minutes = 10;
              id = "normal";
              trigger = "template";

              value_template = ''
                {{ states('${sensor}') | float(9999)
                   < states('${target}') | float(800) }}
              '';
            }
          ];
        };
    in
    {
      config = lib.mkIf config.my.home-assistant.enable {
        services.home-assistant.config = {
          # The ventilators are master/slave pairs (kitchen + office,
          # bedroom + bathroom): a master's mode and "powerful" boost
          # carry over to its slave. "ventilate" is the normal
          # heat-recovery mode; a boost switches the pair to exhaust.
          "automation manual" = [
            {
              alias = "Bathroom: boost ventilation on shower";
              id = "bathroom_shower_boost_on";

              actions = [
                {
                  action = "select.select_option";
                  data.option = "exhaust";
                  target.entity_id = "select.bedroom_mode";
                }
                {
                  action = "switch.turn_on";
                  target.entity_id = "switch.bedroom_ventilator_powerful";
                }
              ];

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
            }
            {
              alias = "Bathroom: end shower boost";
              id = "bathroom_shower_boost_off";

              actions = [
                {
                  action = "switch.turn_off";
                  target.entity_id = "switch.bedroom_ventilator_powerful";
                }
                {
                  action = "select.select_option";
                  data.option = "ventilate";
                  target.entity_id = "select.bedroom_mode";
                }
              ];

              triggers = [
                {
                  for.minutes = 5;
                  trigger = "template";

                  value_template = ''
                    {{ states('sensor.temperatuur_sensor_humidity') | float(0)
                       <= states('sensor.bathroom_humidity_baseline') | float(0) + 3 }}
                  '';
                }
                # Cap, in case humidity never settles back down.
                {
                  entity_id = "switch.bedroom_ventilator_powerful";
                  for.minutes = 45;
                  to = "on";
                  trigger = "state";
                }
              ];
            }
            {
              alias = "Kitchen: cooking boost";
              id = "kitchen_cooking_boost";

              # The switch is the boost: turning it on starts it, turning
              # it off (by hand, or itself after 30 minutes) ends it.
              # Meanwhile the bedroom pair supplies, so the house stays
              # balanced and fresh air sweeps from the bedrooms to the
              # kitchen. It only touches the bedroom pair when that is in
              # its normal mode, so a shower boost there wins.
              mode = "restart";

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
                          data.option = "exhaust";
                          target.entity_id = "select.kitchen_mode";
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
                              data.option = "supply";
                              target.entity_id = "select.bedroom_mode";
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
                          data.option = "ventilate";
                          target.entity_id = "select.kitchen_mode";
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
                              data.option = "ventilate";
                              target.entity_id = "select.bedroom_mode";
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

              triggers = [
                {
                  entity_id = "input_boolean.cooking_boost";
                  from = "off";
                  id = "start";
                  to = "on";
                  trigger = "state";
                }
                {
                  entity_id = "input_boolean.cooking_boost";
                  from = "on";
                  id = "end";
                  to = "off";
                  trigger = "state";
                }
                # A restart loses the 30-minute delay, so end any boost
                # that was running.
                {
                  event = "start";
                  id = "startup";
                  trigger = "homeassistant";
                }
              ];
            }
            {
              alias = "Ventilation: free cooling";
              id = "free_cooling";

              actions = [
                {
                  "else" = [
                    {
                      action = "switch.turn_off";

                      target.entity_id = [
                        "switch.living_room_ventilator_free_cooling"
                        "switch.bedroom_ventilator_free_cooling"
                      ];
                    }
                  ];

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
                }
              ];

              # Indoor is the bathroom sensor, so a shower must not count
              # as a warm house. A heated bathroom on a mild day looks the
              # same as a summer evening, so it only runs May-September.
              triggers = [
                {
                  for.minutes = 30;
                  id = "on";
                  trigger = "template";

                  value_template = ''
                    {% set indoor = states('sensor.temperatuur_sensor_temperature') | float(0) %}
                    {% set outdoor = states('sensor.bedroom_current_temperature') | float(99) %}
                    {% set shower = states('sensor.temperatuur_sensor_humidity') | float(100)
                       >= states('sensor.bathroom_humidity_baseline') | float(0) + 5 %}
                    {{ now().month in [5, 6, 7, 8, 9]
                       and indoor > 24 and outdoor >= 12 and outdoor <= indoor - 2 and not shower }}
                  '';
                }
                {
                  for.minutes = 15;
                  id = "off";
                  trigger = "template";

                  value_template = ''
                    {% set indoor = states('sensor.temperatuur_sensor_temperature') | float(0) %}
                    {% set outdoor = states('sensor.bedroom_current_temperature') | float(0) %}
                    {{ now().month not in [5, 6, 7, 8, 9]
                       or indoor < 22 or outdoor >= indoor or outdoor < 10 }}
                  '';
                }
              ];
            }
            (co2Speed {
              alias = "Kitchen: more air when CO2 is high";
              fan = "fan.kitchen_fan";
              id = "kitchen_co2_speed";
              sensor = "sensor.living_room_ventilator_uitvoer_co2";
              target = "number.living_room_ventilator_co2_target";
            })
            (co2Speed {
              alias = "Bedroom: more air when CO2 is high";
              fan = "fan.bedroom_fan";
              id = "bedroom_co2_speed";
              sensor = "sensor.bedroom_co2";
              target = "number.bedroom_ventilator_co2_target";
            })
          ];

          input_boolean.cooking_boost = {
            icon = "mdi:fan-chevron-up";
            name = "Cooking boost";
          };

          # What "normal" bathroom humidity is right now, for spotting
          # showers. Time-weighted, so the quick sensor updates during a
          # shower don't drag it up.
          sensor = [
            {
              entity_id = "sensor.temperatuur_sensor_humidity";
              keep_last_sample = true;
              max_age.hours = 3;
              name = "Bathroom humidity baseline";
              platform = "statistics";
              sampling_size = 1000;
              state_characteristic = "average_step";
              unique_id = "bathroom_humidity_baseline";
            }
          ];
        };
      };
    };
}

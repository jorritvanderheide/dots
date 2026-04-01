{
  flake.nixosModules.email = {
    config = {
      my.preservation.homeDirectories = [
        ".thunderbird"
      ];

      home-manager.sharedModules = [
        {
          programs.thunderbird = {
            enable = true;

            profiles.default = {
              isDefault = true;
            };

            settings = {
              "ldap_2.servers.science.description" = "Radboud Science";
              "ldap_2.servers.science.hostname" = "ldap.science.ru.nl";
              "ldap_2.servers.science.port" = 389;
              "ldap_2.servers.science.basedn" = "o=addressbook";
              "ldap_2.servers.science.dirType" = 0;
              "ldap_2.servers.science.filename" = "abook-science.sqlite";
            };
          };
        }
      ];
    };
  };
}

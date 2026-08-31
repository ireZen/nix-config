{lib, ...}: {
  options.var = lib.mkOption {
    description = "Shared per-host values referenced from both the NixOS and home-manager modules.";
    type = lib.types.submodule {
      options = {
        hostname = lib.mkOption {
          type = lib.types.str;
          description = "System hostname.";
        };

        username = lib.mkOption {
          type = lib.types.str;
          description = "Primary user account name.";
        };

        homeDirectory = lib.mkOption {
          type = lib.types.str;
          description = "Absolute path to the user's home directory.";
        };

        configDirectory = lib.mkOption {
          type = lib.types.str;
          description = "Path to the flake checkout used by system.autoUpgrade.";
        };

        keyboardLayout = lib.mkOption {
          type = lib.types.str;
          default = "us";
          description = "xkb/console keyboard layout.";
        };

        timeZone = lib.mkOption {
          type = lib.types.str;
          description = "System time zone, e.g. \"America/Chicago\".";
        };

        defaultLocale = lib.mkOption {
          type = lib.types.str;
          default = "en_US.UTF-8";
        };

        extraLocale = lib.mkOption {
          type = lib.types.str;
          default = "en_US.UTF-8";
          description = "Locale used for the LC_* category overrides.";
        };

        git = lib.mkOption {
          description = "Identity used by programs.git in home-manager.";
          type = lib.types.submodule {
            options = {
              username = lib.mkOption {type = lib.types.str;};
              email = lib.mkOption {type = lib.types.str;};
            };
          };
        };

        autoUpgrade = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable system.autoUpgrade.";
        };

        autoGarbageCollector = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable the weekly nix.gc timer.";
        };

        usbguard = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Enable services.usbguard with implicitPolicyTarget = \"block\".";
        };

        usbguardRules = lib.mkOption {
          type = lib.types.lines;
          default = "";
          description = "Rule set passed to services.usbguard.rules.";
        };
      };
    };
  };
}

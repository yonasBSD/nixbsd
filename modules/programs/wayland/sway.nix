{ config, pkgs, lib, ... }:

with lib;

let
  cfg = config.programs.sway;

  wrapperOptions = types.submodule {
    options =
      let
        mkWrapperFeature  = default: description: mkOption {
          type = types.bool;
          inherit default;
          example = !default;
          description = "Whether to make use of the ${description}";
        };
      in {
        base = mkWrapperFeature true ''
          base wrapper to execute extra session commands and prepend a
          dbus-run-session to the sway command.
        '';
        gtk = mkWrapperFeature false ''
          wrapGAppsHook wrapper to execute sway with required environment
          variables for GTK applications.
        '';
    };
  };

  genFinalPackage = pkg:
    let
      expectedArgs = lib.naturalSort [
        "extraSessionCommands"
        "extraOptions"
        "withBaseWrapper"
        "withGtkWrapper"
        "isNixOS"
      ];
      existedArgs = with lib;
        naturalSort
        (intersectLists expectedArgs (attrNames (functionArgs pkg.override)));
    in if existedArgs != expectedArgs then
      pkg
    else
      pkg.override {
        extraSessionCommands = cfg.extraSessionCommands;
        extraOptions = cfg.extraOptions;
        withBaseWrapper = cfg.wrapperFeatures.base;
        withGtkWrapper = cfg.wrapperFeatures.gtk;
        isNixOS = true;
      };
in {
  options.programs.sway = {
    enable = mkEnableOption (''
      Sway, the i3-compatible tiling Wayland compositor. You can manually launch
      Sway by executing "exec sway" on a TTY. Copy /etc/sway/config to
      ~/.config/sway/config to modify the default configuration. See
      <https://github.com/swaywm/sway/wiki> and
      "man 5 sway" for more information'');

    package = mkOption {
      type = with types; nullOr package;
      default = pkgs.sway;
      apply = p: if p == null then null else genFinalPackage p;
      defaultText = literalExpression "pkgs.sway";
      description = ''
        Sway package to use. If the package does not contain the override arguments
        `extraSessionCommands`, `extraOptions`, `withBaseWrapper`, `withGtkWrapper`,
        `isNixOS`, then the module options {option}`wrapperFeatures`,
        {option}`wrapperFeatures` and {option}`wrapperFeatures` will have no effect.
        Set to `null` to not add any Sway package to your path. This should be done if
        you want to use the Home Manager Sway module to install Sway.
      '';
    };

    wrapperFeatures = mkOption {
      type = wrapperOptions;
      default = { };
      example = { gtk = true; };
      description = ''
        Attribute set of features to enable in the wrapper.
      '';
    };

    extraSessionCommands = mkOption {
      type = types.lines;
      default = "";
      example = ''
        # SDL:
        export SDL_VIDEODRIVER=wayland
        # QT (needs qt6.qtwayland in systemPackages):
        export QT_QPA_PLATFORM=wayland-egl
        export QT_WAYLAND_DISABLE_WINDOWDECORATION="1"
        # Fix for some Java AWT applications (e.g. Android Studio),
        # use this if they aren't displayed properly:
        export _JAVA_AWT_WM_NONREPARENTING=1
      '';
      description = ''
        Shell commands executed just before Sway is started. See
        <https://github.com/swaywm/sway/wiki/Running-programs-natively-under-wayland>
        and <https://github.com/swaywm/wlroots/blob/master/docs/env_vars.md>
        for some useful environment variables.
      '';
    };

    extraOptions = mkOption {
      type = types.listOf types.str;
      default = [];
      example = [
        "--verbose"
        "--debug"
        "--unsupported-gpu"
      ];
      description = ''
        Command line arguments passed to launch Sway. Please DO NOT report
        issues if you use an unsupported GPU (proprietary drivers).
      '';
    };

    extraPackages = mkOption {
      type = with types; listOf package;
      default = with pkgs; [
        swaylock swayidle foot dmenu
      ];
      defaultText = literalExpression ''
        with pkgs; [ swaylock swayidle foot dmenu ];
      '';
      example = literalExpression ''
        with pkgs; [
          i3status i3status-rust
          termite rofi light
        ]
      '';
      description = ''
        Extra packages to be installed system wide. See
        <https://github.com/swaywm/sway/wiki/Useful-add-ons-for-sway> and
        <https://github.com/swaywm/sway/wiki/i3-Migration-Guide#common-x11-apps-used-on-i3-with-wayland-alternatives>
        for a list of useful software.
      '';
    };

  };

  config = mkIf cfg.enable
    (mkMerge [
      {
        assertions = [
          {
            assertion = cfg.extraSessionCommands != "" -> cfg.wrapperFeatures.base;
            message = ''
              The extraSessionCommands for Sway will not be run if
              wrapperFeatures.base is disabled.
            '';
          }
        ];
        environment = {
          systemPackages = optional (cfg.package != null) cfg.package ++ cfg.extraPackages;
          # Needed for the default wallpaper:
          pathsToLink = optionals (cfg.package != null) [ "/share/backgrounds/sway" ];
          etc = {
            "sway/config.d/nixos.conf".source = pkgs.writeText "nixos.conf" ''
              # Import the most important environment variables into the D-Bus and systemd
              # user environments (e.g. required for screen sharing and Pinentry prompts):
              exec dbus-update-activation-environment --systemd DISPLAY WAYLAND_DISPLAY SWAYSOCK XDG_CURRENT_DESKTOP
            '';
          } // optionalAttrs (cfg.package != null) {
            "sway/config".source = mkOptionDefault "${cfg.package}/etc/sway/config";
          };
        };
        # To make a Sway session available if a display manager like SDDM is enabled:
        services.xserver.displayManager.sessionPackages = optionals (cfg.package != null) [ cfg.package ]; }
      (import ./wayland-session.nix { inherit lib pkgs; })
    ]);

  meta.maintainers = with lib.maintainers; [ primeos colemickens ];
}

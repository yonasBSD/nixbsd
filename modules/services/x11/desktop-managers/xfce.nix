{ config, lib, pkgs, utils, ... }:

with lib;

let
  cfg = config.services.xserver.desktopManager.xfce;
  excludePackages = config.environment.xfce.excludePackages;

in
{
  options = {
    services.xserver.desktopManager.xfce = {
      enable = mkOption {
        type = types.bool;
        default = false;
        description = "Enable the Xfce desktop environment.";
      };

      noDesktop = mkOption {
        type = types.bool;
        default = false;
        description = "Don't install XFCE desktop components (xfdesktop and panel).";
      };

      enableXfwm = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the XFWM (default) window manager.";
      };

      enableScreensaver = mkOption {
        type = types.bool;
        default = true;
        description = "Enable the XFCE screensaver.";
      };
    };

    environment.xfce.excludePackages = mkOption {
      default = [];
      example = literalExpression "[ pkgs.xfce.xfce4-volumed-pulse ]";
      type = types.listOf types.package;
      description = "Which packages XFCE should exclude from the default environment";
    };
  };

  config = mkIf cfg.enable {
    environment.systemPackages = utils.removePackagesByName (with pkgs // pkgs.xfce; [
      glib # for gsettings
      gtk3.out # gtk-update-icon-cache

      gnome-themes-extra
      adwaita-icon-theme
      hicolor-icon-theme
      tango-icon-theme
      xfce4-icon-theme

      desktop-file-utils
      shared-mime-info # for update-mime-database

      # For a polkit authentication agent
      polkit_gnome

      # Needed by Xfce's xinitrc script
      xdg-user-dirs # Update user dirs as described in https://freedesktop.org/wiki/Software/xdg-user-dirs/

      exo
      garcon
      libxfce4ui

      mousepad
      parole
      ristretto
      xfce4-appfinder
      xfce4-notifyd
      xfce4-screenshooter
      xfce4-session
      xfce4-settings
      xfce4-taskmanager
      xfce4-terminal
    ] # TODO: NetworkManager doesn't belong here
      #++ optional config.networking.networkmanager.enable networkmanagerapplet
      #++ optional config.powerManagement.enable xfce4-power-manager
      #++ optionals config.hardware.pulseaudio.enable [
      #  pavucontrol
      #  # volume up/down keys support:
      #  # xfce4-pulseaudio-plugin includes all the functionalities of xfce4-volumed-pulse
      #  # but can only be used with xfce4-panel, so for no-desktop usage we still include
      #  # xfce4-volumed-pulse
      #  (if cfg.noDesktop then xfce4-volumed-pulse else xfce4-pulseaudio-plugin)
      ++ optionals cfg.enableXfwm [
        xfwm4
        xfwm4-themes
      ] ++ optionals (!cfg.noDesktop) [
        xfce4-panel
        xfdesktop
      ] ++ optional cfg.enableScreensaver xfce4-screensaver) excludePackages;

    programs.xfconf.enable = true;
    programs.thunar.enable = true;

    environment.pathsToLink = [
      "/share/xfce4"
      "/lib/xfce4"
      "/share/gtksourceview-3.0"
      "/share/gtksourceview-4.0"
    ];

    services.xserver.desktopManager.session = [{
      name = "xfce";
      desktopNames = [ "XFCE" ];
      bgSupport = true;
      start = ''
        ${pkgs.runtimeShell} ${pkgs.xfce.xfce4-session.xinitrc} &
        waitPID=$!
      '';
    }];

    services.xserver.updateDbusEnvironment = true;
    #services.xserver.gdk-pixbuf.modulePackages = [ pkgs.librsvg ];

    # Enable helpful DBus services.
    #services.udisks2.enable = true;
    security.polkit.enable = true;
    services.accounts-daemon.enable = true;
    #services.upower.enable = config.powerManagement.enable;
    #services.gnome.glib-networking.enable = true;
    #services.gvfs.enable = true;
    #services.tumbler.enable = true;
    #services.system-config-printer.enable = (mkIf config.services.printing.enable (mkDefault true));
    services.xserver.libinput.enable = mkDefault true; # used in xfce4-settings-manager

    # Enable default programs
    programs.dconf.enable = true;

    # Shell integration for VTE terminals
    #programs.bash.vteIntegration = mkDefault true;
    #programs.zsh.vteIntegration = mkDefault true;

    # Systemd services
    #systemd.packages = utils.removePackagesByName (with pkgs.xfce; [
    #  xfce4-notifyd
    #]) excludePackages;

    #security.pam.services.xfce4-screensaver.unixAuth = cfg.enableScreensaver;

    #xdg.portal.configPackages = mkDefault [ pkgs.xfce.xfce4-session ];
  };
}

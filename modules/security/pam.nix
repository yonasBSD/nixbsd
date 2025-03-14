# This module provides configuration for the PAM (Pluggable
# Authentication Modules) system.

{ config, lib, pkgs, ... }:

with lib;

let

  mkRulesTypeOption = type:
    mkOption {
      # These options are experimental and subject to breaking changes without notice.
      description = ''
        PAM `${type}` rules for this service.

        Attribute keys are the name of each rule.
      '';
      type = types.attrsOf (types.submodule ({ name, config, ... }: {
        options = {
          name = mkOption {
            type = types.str;
            description = ''
              Name of this rule.
            '';
            internal = true;
            readOnly = true;
          };
          enable = mkOption {
            type = types.bool;
            default = true;
            description = ''
              Whether this rule is added to the PAM service config file.
            '';
          };
          order = mkOption {
            type = types.int;
            description = ''
              Order of this rule in the service file. Rules are arranged in ascending order of this value.

              ::: {.warning}
              The `order` values for the built-in rules are subject to change. If you assign a constant value to this option, a system update could silently reorder your rule. You could be locked out of your system, or your system could be left wide open. When using this option, set it to a relative offset from another rule's `order` value:

              ```nix
              {
                security.pam.services.login.rules.auth.foo.order =
                  config.security.pam.services.login.rules.auth.unix.order + 10;
              }
              ```
              :::
            '';
          };
          control = mkOption {
            type = types.str;
            description = ''
              Indicates the behavior of the PAM-API should the module fail to succeed in its authentication task. See `control` in {manpage}`pam.conf(5)` for details.
            '';
          };
          modulePath = mkOption {
            type = types.str;
            description = ''
              Either the full filename of the PAM to be used by the application (it begins with a '/'), or a relative pathname from the default module location. See `module-path` in {manpage}`pam.conf(5)` for details.
            '';
          };
          args = mkOption {
            type = types.listOf types.str;
            description = ''
              Tokens that can be used to modify the specific behavior of the given PAM. Such arguments will be documented for each individual module. See `module-arguments` in {manpage}`pam.conf(5)` for details.

              Escaping rules for spaces and square brackets are automatically applied.

              {option}`settings` are automatically added as {option}`args`. It's recommended to use the {option}`settings` option whenever possible so that arguments can be overridden.
            '';
          };
          settings = mkOption {
            type = with types;
              attrsOf (nullOr (oneOf [ bool str int pathInStore ]));
            default = { };
            description = ''
              Settings to add as `module-arguments`.

              Boolean values render just the key if true, and nothing if false. Null values are ignored. All other values are rendered as key-value pairs.
            '';
          };
        };
        config = {
          inherit name;
          # Formats an attrset of settings as args for use as `module-arguments`.
          args = concatLists (flip mapAttrsToList config.settings (name: value:
            if isBool value then
              optional value name
            else
              optional (value != null) "${name}=${toString value}"));
        };
      }));
    };

  parentConfig = config;

  pamOpts = { config, name, ... }:
    let cfg = config;
    in let config = parentConfig;
    in {

      options = {

        name = mkOption {
          example = "sshd";
          type = types.str;
          description = "Name of the PAM service.";
        };

        rules = mkOption {
          # This option is experimental and subject to breaking changes without notice.
          visible = false;

          description = ''
            PAM rules for this service.

            ::: {.warning}
            This option and its suboptions are experimental and subject to breaking changes without notice.

            If you use this option in your system configuration, you will need to manually monitor this module for any changes. Otherwise, failure to adjust your configuration properly could lead to you being locked out of your system, or worse, your system could be left wide open to attackers.

            If you share configuration examples that use this option, you MUST include this warning so that users are informed.

            You may freely use this option within `nixpkgs`, and future changes will account for those use sites.
            :::
          '';
          type = types.submodule {
            options = genAttrs [ "account" "auth" "password" "session" ]
              mkRulesTypeOption;
          };
        };

        unixAuth = mkOption {
          default = true;
          type = types.bool;
          description = ''
            Whether users can log in with passwords defined in
            {file}`/etc/shadow`.
          '';
        };

        rootOK = mkOption {
          default = false;
          type = types.bool;
          description = ''
            If set, root doesn't need to authenticate (e.g. for the
            {command}`useradd` service).
          '';
        };

        p11Auth = mkOption {
          default = config.security.pam.p11.enable;
          defaultText = literalExpression "config.security.pam.p11.enable";
          type = types.bool;
          description = ''
            If set, keys listed in
            {file}`~/.ssh/authorized_keys` and
            {file}`~/.eid/authorized_certificates`
            can be used to log in with the associated PKCS#11 tokens.
          '';
        };

        u2fAuth = mkOption {
          default = config.security.pam.u2f.enable;
          defaultText = literalExpression "config.security.pam.u2f.enable";
          type = types.bool;
          description = ''
            If set, users listed in
            {file}`$XDG_CONFIG_HOME/Yubico/u2f_keys` (or
            {file}`$HOME/.config/Yubico/u2f_keys` if XDG variable is
            not set) are able to log in with the associated U2F key. Path can be
            changed using {option}`security.pam.u2f.authFile` option.
          '';
        };

        usshAuth = mkOption {
          default = false;
          type = types.bool;
          description = ''
            If set, users with an SSH certificate containing an authorized principal
            in their SSH agent are able to log in. Specific options are controlled
            using the {option}`security.pam.ussh` options.

            Note that the  {option}`security.pam.ussh.enable` must also be
            set for this option to take effect.
          '';
        };

        yubicoAuth = mkOption {
          default = config.security.pam.yubico.enable;
          defaultText = literalExpression "config.security.pam.yubico.enable";
          type = types.bool;
          description = ''
            If set, users listed in
            {file}`~/.yubico/authorized_yubikeys`
            are able to log in with the associated Yubikey tokens.
          '';
        };

        googleAuthenticator = {
          enable = mkOption {
            default = false;
            type = types.bool;
            description = ''
              If set, users with enabled Google Authenticator (created
              {file}`~/.google_authenticator`) will be required
              to provide Google Authenticator token to log in.
            '';
          };
        };

        usbAuth = mkOption {
          default = config.security.pam.usb.enable;
          defaultText = literalExpression "config.security.pam.usb.enable";
          type = types.bool;
          description = ''
            If set, users listed in
            {file}`/etc/pamusb.conf` are able to log in
            with the associated USB key.
          '';
        };

        otpwAuth = mkOption {
          default = config.security.pam.enableOTPW;
          defaultText = literalExpression "config.security.pam.enableOTPW";
          type = types.bool;
          description = ''
            If set, the OTPW system will be used (if
            {file}`~/.otpw` exists).
          '';
        };

        googleOsLoginAccountVerification = mkOption {
          default = false;
          type = types.bool;
          description = ''
            If set, will use the Google OS Login PAM modules
            (`pam_oslogin_login`,
            `pam_oslogin_admin`) to verify possible OS Login
            users and set sudoers configuration accordingly.
            This only makes sense to enable for the `sshd` PAM
            service.
          '';
        };

        googleOsLoginAuthentication = mkOption {
          default = false;
          type = types.bool;
          description = ''
            If set, will use the `pam_oslogin_login`'s user
            authentication methods to authenticate users using 2FA.
            This only makes sense to enable for the `sshd` PAM
            service.
          '';
        };

        mysqlAuth = mkOption {
          default = config.users.mysql.enable;
          defaultText = literalExpression "config.users.mysql.enable";
          type = types.bool;
          description = ''
            If set, the `pam_mysql` module will be used to
            authenticate users against a MySQL/MariaDB database.
          '';
        };

        fprintAuth = mkOption {
          default = config.services.fprintd.enable;
          defaultText = literalExpression "config.services.fprintd.enable";
          type = types.bool;
          description = ''
            If set, fingerprint reader will be used (if exists and
            your fingerprints are enrolled).
          '';
        };

        oathAuth = mkOption {
          default = config.security.pam.oath.enable;
          defaultText = literalExpression "config.security.pam.oath.enable";
          type = types.bool;
          description = ''
            If set, the OATH Toolkit will be used.
          '';
        };

        sshAgentAuth = mkOption {
          default = false;
          type = types.bool;
          description = ''
            If set, the calling user's SSH agent is used to authenticate
            against the keys in the calling user's
            {file}`~/.ssh/authorized_keys`.  This is useful
            for {command}`sudo` on password-less remote systems.
          '';
        };

        duoSecurity = {
          enable = mkOption {
            default = false;
            type = types.bool;
            description = ''
              If set, use the Duo Security pam module
              `pam_duo` for authentication.  Requires
              configuration of {option}`security.duosec` options.
            '';
          };
        };

        startSession = mkOption {
          default = false;
          type = types.bool;
          description = ''
            If set, the service will register a new session with
            systemd's login manager.  For local sessions, this will give
            the user access to audio devices, CD-ROM drives.  In the
            default PolicyKit configuration, it also allows the user to
            reboot the system.
          '';
        };

        setLoginUid = mkOption {
          type = types.bool;
          description = ''
            Set the login uid of the process
            ({file}`/proc/self/loginuid`) for auditing
            purposes.  The login uid is only set by ‘entry points’ like
            {command}`login` and {command}`sshd`, not by
            commands like {command}`sudo`.
          '';
        };

        ttyAudit = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Enable or disable TTY auditing for specified users
            '';
          };

          enablePattern = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              For each user matching one of comma-separated
              glob patterns, enable TTY auditing
            '';
          };

          disablePattern = mkOption {
            type = types.nullOr types.str;
            default = null;
            description = ''
              For each user matching one of comma-separated
              glob patterns, disable TTY auditing
            '';
          };

          openOnly = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Set the TTY audit flag when opening the session,
              but do not restore it when closing the session.
              Using this option is necessary for some services
              that don't fork() to run the authenticated session,
              such as sudo.
            '';
          };
        };

        forwardXAuth = mkOption {
          default = false;
          type = types.bool;
          description = ''
            Whether X authentication keys should be passed from the
            calling user to the target user (e.g. for
            {command}`su`)
          '';
        };

        pamMount = mkOption {
          default = config.security.pam.mount.enable;
          defaultText = literalExpression "config.security.pam.mount.enable";
          type = types.bool;
          description = ''
            Enable PAM mount (pam_mount) system to mount filesystems on user login.
          '';
        };

        allowNullPassword = mkOption {
          default = false;
          type = types.bool;
          description = ''
            Whether to allow logging into accounts that have no password
            set (i.e., have an empty password field in
            {file}`/etc/passwd` or
            {file}`/etc/group`).  This does not enable
            logging into disabled accounts (i.e., that have the password
            field set to `!`).  Note that regardless of
            what the pam_unix documentation says, accounts with hashed
            empty passwords are always allowed to log in.
          '';
        };

        nodelay = mkOption {
          default = false;
          type = types.bool;
          description = ''
            Whether the delay after typing a wrong password should be disabled.
          '';
        };

        requireWheel = mkOption {
          default = false;
          type = types.bool;
          description = ''
            Whether to permit root access only to members of group wheel.
          '';
        };

        limits = mkOption {
          default = [ ];
          type = limitsType;
          description = ''
            Attribute set describing resource limits.  Defaults to the
            value of {option}`security.pam.loginLimits`.
            The meaning of the values is explained in {manpage}`limits.conf(5)`.
          '';
        };

        showMotd = mkOption {
          default = false;
          type = types.bool;
          description = "Whether to show the message of the day.";
        };

        makeHomeDir = mkOption {
          default = false;
          type = types.bool;
          description = ''
            Whether to try to create home directories for users
            with `$HOME`s pointing to nonexistent
            locations on session login.
          '';
        };

        updateWtmp = mkOption {
          default = false;
          type = types.bool;
          description = "Whether to update {file}`/var/log/wtmp`.";
        };

        logFailures = mkOption {
          default = false;
          type = types.bool;
          description = 
            "Whether to log authentication failures in {file}`/var/log/faillog`.";
        };

        enableAppArmor = mkOption {
          default = false;
          type = types.bool;
          description = ''
            Enable support for attaching AppArmor profiles at the
            user/group level, e.g., as part of a role based access
            control scheme.
          '';
        };

        enableKwallet = mkOption {
          default = false;
          type = types.bool;
          description = ''
            If enabled, pam_wallet will attempt to automatically unlock the
            user's default KDE wallet upon login. If the user has no wallet named
            "kdewallet", or the login password does not match their wallet
            password, KDE will prompt separately after login.
          '';
        };
        sssdStrictAccess = mkOption {
          default = false;
          type = types.bool;
          description = "enforce sssd access control";
        };

        enableGnomeKeyring = mkOption {
          default = false;
          type = types.bool;
          description = ''
            If enabled, pam_gnome_keyring will attempt to automatically unlock the
            user's default Gnome keyring upon login. If the user login password does
            not match their keyring password, Gnome Keyring will prompt separately
            after login.
          '';
        };

        failDelay = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              If enabled, this will replace the `FAIL_DELAY` setting from `login.defs`.
              Change the delay on failure per-application.
            '';
          };

          delay = mkOption {
            default = 3000000;
            type = types.int;
            example = 1000000;
            description =
              "The delay time (in microseconds) on failure.";
          };
        };

        gnupg = {
          enable = mkOption {
            type = types.bool;
            default = false;
            description = ''
              If enabled, pam_gnupg will attempt to automatically unlock the
              user's GPG keys with the login password via
              {command}`gpg-agent`. The keygrips of all keys to be
              unlocked should be written to {file}`~/.pam-gnupg`,
              and can be queried with {command}`gpg -K --with-keygrip`.
              Presetting passphrases must be enabled by adding
              `allow-preset-passphrase` in
              {file}`~/.gnupg/gpg-agent.conf`.
            '';
          };

          noAutostart = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Don't start {command}`gpg-agent` if it is not running.
              Useful in conjunction with starting {command}`gpg-agent` as
              a systemd user service.
            '';
          };

          storeOnly = mkOption {
            type = types.bool;
            default = false;
            description = ''
              Don't send the password immediately after login, but store for PAM
              `session`.
            '';
          };
        };

        zfs = mkOption {
          default = config.security.pam.zfs.enable;
          defaultText = literalExpression "config.security.pam.zfs.enable";
          type = types.bool;
          description = ''
            Enable unlocking and mounting of encrypted ZFS home dataset at login.
          '';
        };

        text = mkOption {
          type = types.nullOr types.lines;
          description = "Contents of the PAM service file.";
        };

      };

      # TODO: nixos/tests/pam/pam-file-contents.nix
      config = {
        name = mkDefault name;
        setLoginUid = mkDefault cfg.startSession;
        limits = mkDefault config.security.pam.loginLimits;

        text = let
          ensureUniqueOrder = type: rules:
            let
              checkPair = a: b:
                assert assertMsg (a.order != b.order)
                  "security.pam.services.${name}.rules.${type}: rules '${a.name}' and '${b.name}' cannot have the same order value (${
                    toString a.order
                  })";
                b;
              checked = zipListsWith checkPair rules (drop 1 rules);
            in take 1 rules ++ checked;
          # Formats a string for use in `module-arguments`. See `man pam.conf`.
          formatModuleArgument = token:
            if hasInfix " " token then
              "[${replaceStrings [ "]" ] [ "\\]" ] token}]"
            else
              token;
          formatRules = type:
            pipe cfg.rules.${type} [
              attrValues
              (filter (rule: rule.enable))
              (sort (a: b: a.order < b.order))
              (ensureUniqueOrder type)
              (map (rule:
                concatStringsSep " " ([ type rule.control rule.modulePath ]
                  ++ map formatModuleArgument rule.args
                  ++ [ "# ${rule.name} (order ${toString rule.order})" ])))
              (concatStringsSep "\n")
            ];
        in mkDefault ''
          # Account management.
          ${formatRules "account"}

          # Authentication management.
          ${formatRules "auth"}

          # Password management.
          ${formatRules "password"}

          # Session management.
          ${formatRules "session"}
        '';

        rules = let
          autoOrderRules = flip pipe [
            (imap1 (index: rule:
              rule // {
                order = mkDefault (10000 + index * 100);
              }))
            (map (rule: nameValuePair rule.name (removeAttrs rule [ "name" ])))
            listToAttrs
          ];
        in {
          account = autoOrderRules [
            {
              name = "login_access";
              control = "required";
              modulePath = "pam_login_access.so";
            }
            {
              name = "unix";
              control = "required";
              modulePath = "pam_unix.so";
            }
          ];

          auth = autoOrderRules [
            {
              name = "unix";
              enable = cfg.unixAuth;
              control = "sufficient";
              modulePath = "pam_unix.so";
              settings = {
                nullok = cfg.allowNullPassword;
                inherit (cfg) nodelay;
                likeauth = true;
                try_first_pass = true;
              };
            }
            {
              name = "deny";
              control = "required";
              modulePath = "pam_deny.so";
            }
          ];

          password = autoOrderRules [{
            name = "unix";
            control = "sufficient";
            modulePath = "pam_unix.so";
            settings = {
              nullok = true;
              yescrypt = true;
            };
          }];

          session = autoOrderRules [
            {
              name = "lastlog";
              enable = cfg.updateWtmp;
              control = "required";
              modulePath = "pam_lastlog.so";
              settings = { silent = true; };
            }
            {
              name = "rcSession";
              enable = cfg.startSession;
              control = "required";
              modulePath = "pam_exec.so";
              settings = {
                seteuid = true;
              };
              args = ["/bin/sh" "-c" "USER_LOGIN=$PAM_USER /bin/sh /etc/rc"];
            }
          ];
        };

      };
    };

  limitsType = with lib.types;
    listOf (submodule ({ ... }: {
      options = {
        domain = mkOption {
          description =
            "Username, groupname, or wildcard this limit applies to";
          example = "@wheel";
          type = str;
        };

        type = mkOption {
          description = "Type of this limit";
          type = enum [ "-" "hard" "soft" ];
          default = "-";
        };

        item = mkOption {
          description = "Item this limit applies to";
          type = enum [
            "core"
            "data"
            "fsize"
            "memlock"
            "nofile"
            "rss"
            "stack"
            "cpu"
            "nproc"
            "as"
            "maxlogins"
            "maxsyslogins"
            "priority"
            "locks"
            "sigpending"
            "msgqueue"
            "nice"
            "rtprio"
          ];
        };

        value = mkOption {
          description = "Value of this limit";
          type = oneOf [ str int ];
        };
      };
    }));

  makePAMService = name: service: {
    name = "pam.d/${name}";
    value.source = pkgs.writeText "${name}.pam" service.text;
  };

  optionalSudoConfigForSSHAgentAuth =
    optionalString config.security.pam.enableSSHAgentAuth ''
      # Keep SSH_AUTH_SOCK so that pam_ssh_agent_auth.so can do its magic.
      Defaults env_keep+=SSH_AUTH_SOCK
    '';

in {

  meta.maintainers = [ maintainers.majiir ];

  imports = [
    (mkRenamedOptionModule [ "security" "pam" "enableU2F" ] [
      "security"
      "pam"
      "u2f"
      "enable"
    ])
  ];

  ###### interface

  options = {

    security.pam.loginLimits = mkOption {
      default = [ ];
      type = limitsType;
      example = [
        {
          domain = "ftp";
          type = "hard";
          item = "nproc";
          value = "0";
        }
        {
          domain = "@student";
          type = "-";
          item = "maxlogins";
          value = "4";
        }
      ];

      description = ''
        Define resource limits that should apply to users or groups.
        Each item in the list should be an attribute set with a
        {var}`domain`, {var}`type`,
        {var}`item`, and {var}`value`
        attribute.  The syntax and semantics of these attributes
        must be that described in {manpage}`limits.conf(5)`.

        Note that these limits do not apply to systemd services,
        whose limits can be changed via {option}`systemd.extraConfig`
        instead.
      '';
    };

    security.pam.services = mkOption {
      default = { };
      type = with types; attrsOf (submodule pamOpts);
      description = ''
        This option defines the PAM services.  A service typically
        corresponds to a program that uses PAM,
        e.g. {command}`login` or {command}`passwd`.
        Each attribute of this set defines a PAM service, with the attribute name
        defining the name of the service.
      '';
    };

    security.pam.makeHomeDir.skelDirectory = mkOption {
      type = types.str;
      default = "/var/empty";
      example = "/etc/skel";
      description = ''
        Path to skeleton directory whose contents are copied to home
        directories newly created by `pam_mkhomedir`.
      '';
    };

    security.pam.makeHomeDir.umask = mkOption {
      type = types.str;
      default = "0077";
      example = "0022";
      description = ''
        The user file mode creation mask to use on home directories
        newly created by `pam_mkhomedir`.
      '';
    };

    security.pam.enableSSHAgentAuth = mkOption {
      type = types.bool;
      default = false;
      description = ''
        Enable sudo logins if the user's SSH agent provides a key
        present in {file}`~/.ssh/authorized_keys`.
        This allows machines to exclusively use SSH keys instead of
        passwords.
      '';
    };

    security.pam.enableOTPW =
      mkEnableOption ("the OTPW (one-time password) PAM module");

    security.pam.dp9ik = {
      enable = mkEnableOption (''
        the dp9ik pam module provided by tlsclient.

        If set, users can be authenticated against the 9front
        authentication server given in {option}`security.pam.dp9ik.authserver`.
      '');
      control = mkOption {
        default = "sufficient";
        type = types.str;
        description = ''
          This option sets the pam "control" used for this module.
        '';
      };
      authserver = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          This controls the hostname for the 9front authentication server
          that users will be authenticated against.
        '';
      };
    };

    security.pam.krb5 = {
      enable = mkOption {
        default = config.krb5.enable;
        defaultText = literalExpression "config.krb5.enable";
        type = types.bool;
        description = ''
          Enables Kerberos PAM modules (`pam-krb5`,
          `pam-ccreds`).

          If set, users can authenticate with their Kerberos password.
          This requires a valid Kerberos configuration
          (`config.krb5.enable` should be set to
          `true`).

          Note that the Kerberos PAM modules are not necessary when using SSS
          to handle Kerberos authentication.
        '';
      };
    };

    security.pam.p11 = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Enables P11 PAM (`pam_p11`) module.

          If set, users can log in with SSH keys and PKCS#11 tokens.

          More information can be found [here](https://github.com/OpenSC/pam_p11).
        '';
      };

      control = mkOption {
        default = "sufficient";
        type = types.enum [ "required" "requisite" "sufficient" "optional" ];
        description = ''
          This option sets pam "control".
          If you want to have multi factor authentication, use "required".
          If you want to use the PKCS#11 device instead of the regular password,
          use "sufficient".

          Read
          {manpage}`pam.conf(5)`
          for better understanding of this option.
        '';
      };
    };

    security.pam.u2f = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Enables U2F PAM (`pam-u2f`) module.

          If set, users listed in
          {file}`$XDG_CONFIG_HOME/Yubico/u2f_keys` (or
          {file}`$HOME/.config/Yubico/u2f_keys` if XDG variable is
          not set) are able to log in with the associated U2F key. The path can
          be changed using {option}`security.pam.u2f.authFile` option.

          File format is:
          `username:first_keyHandle,first_public_key: second_keyHandle,second_public_key`
          This file can be generated using {command}`pamu2fcfg` command.

          More information can be found [here](https://developers.yubico.com/pam-u2f/).
        '';
      };

      authFile = mkOption {
        default = null;
        type = with types; nullOr path;
        description = ''
          By default `pam-u2f` module reads the keys from
          {file}`$XDG_CONFIG_HOME/Yubico/u2f_keys` (or
          {file}`$HOME/.config/Yubico/u2f_keys` if XDG variable is
          not set).

          If you want to change auth file locations or centralize database (for
          example use {file}`/etc/u2f-mappings`) you can set this
          option.

          File format is:
          `username:first_keyHandle,first_public_key: second_keyHandle,second_public_key`
          This file can be generated using {command}`pamu2fcfg` command.

          More information can be found [here](https://developers.yubico.com/pam-u2f/).
        '';
      };

      appId = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          By default `pam-u2f` module sets the application
          ID to `pam://$HOSTNAME`.

          When using {command}`pamu2fcfg`, you can specify your
          application ID with the `-i` flag.

          More information can be found [here](https://developers.yubico.com/pam-u2f/Manuals/pam_u2f.8.html)
        '';
      };

      origin = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          By default `pam-u2f` module sets the origin
          to `pam://$HOSTNAME`.
          Setting origin to an host independent value will allow you to
          reuse credentials across machines

          When using {command}`pamu2fcfg`, you can specify your
          application ID with the `-o` flag.

          More information can be found [here](https://developers.yubico.com/pam-u2f/Manuals/pam_u2f.8.html)
        '';
      };

      control = mkOption {
        default = "sufficient";
        type = types.enum [ "required" "requisite" "sufficient" "optional" ];
        description = ''
          This option sets pam "control".
          If you want to have multi factor authentication, use "required".
          If you want to use U2F device instead of regular password, use "sufficient".

          Read
          {manpage}`pam.conf(5)`
          for better understanding of this option.
        '';
      };

      debug = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Debug output to stderr.
        '';
      };

      interactive = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Set to prompt a message and wait before testing the presence of a U2F device.
          Recommended if your device doesn’t have a tactile trigger.
        '';
      };

      cue = mkOption {
        default = false;
        type = types.bool;
        description = ''
          By default `pam-u2f` module does not inform user
          that he needs to use the u2f device, it just waits without a prompt.

          If you set this option to `true`,
          `cue` option is added to `pam-u2f`
          module and reminder message will be displayed.
        '';
      };
    };

    security.pam.ussh = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Enables Uber's USSH PAM (`pam-ussh`) module.

          This is similar to `pam-ssh-agent`, except that
          the presence of a CA-signed SSH key with a valid principal is checked
          instead.

          Note that this module must both be enabled using this option and on a
          per-PAM-service level as well (using `usshAuth`).

          More information can be found [here](https://github.com/uber/pam-ussh).
        '';
      };

      caFile = mkOption {
        default = null;
        type = with types; nullOr path;
        description = ''
          By default `pam-ussh` reads the trusted user CA keys
          from {file}`/etc/ssh/trusted_user_ca`.

          This should be set the same as your `TrustedUserCAKeys`
          option for sshd.
        '';
      };

      authorizedPrincipals = mkOption {
        default = null;
        type = with types; nullOr commas;
        description = ''
          Comma-separated list of authorized principals to permit; if the user
          presents a certificate with one of these principals, then they will be
          authorized.

          Note that `pam-ussh` also requires that the certificate
          contain a principal matching the user's username. The principals from
          this list are in addition to those principals.

          Mutually exclusive with `authorizedPrincipalsFile`.
        '';
      };

      authorizedPrincipalsFile = mkOption {
        default = null;
        type = with types; nullOr path;
        description = ''
          Path to a list of principals; if the user presents a certificate with
          one of these principals, then they will be authorized.

          Note that `pam-ussh` also requires that the certificate
          contain a principal matching the user's username. The principals from
          this file are in addition to those principals.

          Mutually exclusive with `authorizedPrincipals`.
        '';
      };

      group = mkOption {
        default = null;
        type = with types; nullOr str;
        description = ''
          If set, then the authenticating user must be a member of this group
          to use this module.
        '';
      };

      control = mkOption {
        default = "sufficient";
        type = types.enum [ "required" "requisite" "sufficient" "optional" ];
        description = ''
          This option sets pam "control".
          If you want to have multi factor authentication, use "required".
          If you want to use the SSH certificate instead of the regular password,
          use "sufficient".

          Read
          {manpage}`pam.conf(5)`
          for better understanding of this option.
        '';
      };
    };

    security.pam.yubico = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Enables Yubico PAM (`yubico-pam`) module.

          If set, users listed in
          {file}`~/.yubico/authorized_yubikeys`
          are able to log in with the associated Yubikey tokens.

          The file must have only one line:
          `username:yubikey_token_id1:yubikey_token_id2`
          More information can be found [here](https://developers.yubico.com/yubico-pam/).
        '';
      };
      control = mkOption {
        default = "sufficient";
        type = types.enum [ "required" "requisite" "sufficient" "optional" ];
        description = ''
          This option sets pam "control".
          If you want to have multi factor authentication, use "required".
          If you want to use Yubikey instead of regular password, use "sufficient".

          Read
          {manpage}`pam.conf(5)`
          for better understanding of this option.
        '';
      };
      id = mkOption {
        example = "42";
        type = types.str;
        description = "client id";
      };

      debug = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Debug output to stderr.
        '';
      };
      mode = mkOption {
        default = "client";
        type = types.enum [ "client" "challenge-response" ];
        description = ''
          Mode of operation.

          Use "client" for online validation with a YubiKey validation service such as
          the YubiCloud.

          Use "challenge-response" for offline validation using YubiKeys with HMAC-SHA-1
          Challenge-Response configurations. See the man-page ykpamcfg(1) for further
          details on how to configure offline Challenge-Response validation.

          More information can be found [here](https://developers.yubico.com/yubico-pam/Authentication_Using_Challenge-Response.html).
        '';
      };
      challengeResponsePath = mkOption {
        default = null;
        type = types.nullOr types.path;
        description = ''
          If not null, set the path used by yubico pam module where the challenge expected response is stored.

          More information can be found [here](https://developers.yubico.com/yubico-pam/Authentication_Using_Challenge-Response.html).
        '';
      };
    };

    security.pam.zfs = {
      enable = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Enable unlocking and mounting of encrypted ZFS home dataset at login.
        '';
      };

      homes = mkOption {
        example = "rpool/home";
        default = "rpool/home";
        type = types.str;
        description = ''
          Prefix of home datasets. This value will be concatenated with
          `"/" + <username>` in order to determine the home dataset to unlock.
        '';
      };

      noUnmount = mkOption {
        default = false;
        type = types.bool;
        description = ''
          Do not unmount home dataset on logout.
        '';
      };
    };

    security.pam.enableEcryptfs = mkEnableOption (
      "eCryptfs PAM module (mounting ecryptfs home directory on login)");
    security.pam.enableFscrypt = mkEnableOption (''
      fscrypt to automatically unlock directories with the user's login password.

      This also enables a service at security.pam.services.fscrypt which is used by
      fscrypt to verify the user's password when setting up a new protector. If you
      use something other than pam_unix to verify user passwords, please remember to
      adjust this PAM service.
    '');

    users.motd = mkOption {
      default = null;
      example =
        "Today is Sweetmorn, the 4th day of The Aftermath in the YOLD 3178.";
      type = types.nullOr types.lines;
      description =
        "Message of the day shown to users when they log in.";
    };

    users.motdFile = mkOption {
      default = null;
      example = "/etc/motd";
      type = types.nullOr types.path;
      description = 
        "A file containing the message of the day shown to users when they log in.";
    };
  };

  ###### implementation

  config = lib.mkIf pkgs.stdenv.hostPlatform.isFreeBSD {
    assertions = [
      {
        assertion = config.users.motd == null || config.users.motdFile == null;
        message = ''
          Only one of users.motd and users.motdFile can be set.
        '';
      }
      {
        assertion = config.security.pam.zfs.enable
          -> (config.boot.zfs.enabled || config.boot.zfs.enableUnstable);
        message = ''
          `security.pam.zfs.enable` requires enabling ZFS (`boot.zfs.enabled` or `boot.zfs.enableUnstable`).
        '';
      }
    ];

    #environment.systemPackages =
    #  # Include the PAM modules in the system path mostly for the manpages.
    #  [ pkgs.pam ]
    #  ++ optional config.users.ldap.enable pam_ldap
    #  ++ optional config.services.kanidm.enablePam pkgs.kanidm
    #  ++ optional config.services.sssd.enable pkgs.sssd
    #  ++ optionals config.security.pam.krb5.enable [pam_krb5 pam_ccreds]
    #  ++ optionals config.security.pam.enableOTPW [ pkgs.otpw ]
    #  ++ optionals config.security.pam.oath.enable [ pkgs.oath-toolkit ]
    #  ++ optionals config.security.pam.p11.enable [ pkgs.pam_p11 ]
    #  ++ optionals config.security.pam.enableFscrypt [ pkgs.fscrypt-experimental ]
    #  ++ optionals config.security.pam.u2f.enable [ pkgs.pam_u2f ];

    boot.supportedFilesystems =
      optionals config.security.pam.enableEcryptfs [ "ecryptfs" ];

    #security.wrappers = {
    #  unix_chkpwd = {
    #    setuid = true;
    #    owner = "root";
    #    group = "root";
    #    source = "${pkgs.pam}/bin/unix_chkpwd";
    #  };
    #};

    environment.etc = mapAttrs' makePAMService config.security.pam.services;

    security.pam.services = {
      other.text = ''
        auth     required pam_deny.so
        account  required pam_deny.so
        password required pam_deny.so
        session  required pam_deny.so
      '';
      system.text = ''
        # auth
        #auth		sufficient	pam_krb5.so		no_warn try_first_pass
        #auth		sufficient	pam_ssh.so		no_warn try_first_pass
        auth		required	pam_unix.so		no_warn try_first_pass nullok

        # account
        #account	required	pam_krb5.so
        account		required	pam_login_access.so
        account		required	pam_unix.so

        # session
        #session	optional	pam_ssh.so		want_agent
        session		required	pam_lastlog.so		no_fail

        # password
        #password	sufficient	pam_krb5.so		no_warn try_first_pass
        password	required	pam_unix.so		no_warn try_first_pass

      '';
    };

    #security.sudo.extraConfig = optionalSudoConfigForSSHAgentAuth;
    #security.sudo-rs.extraConfig = optionalSudoConfigForSSHAgentAuth;
  };
}

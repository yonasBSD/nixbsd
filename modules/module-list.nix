nixpkgsPath:
let extPath = "${nixpkgsPath}/nixos/modules";
in [
  "${extPath}/config/shells-environment.nix"
  "${extPath}/config/system-environment.nix"
  "${extPath}/misc/assertions.nix"
  "${extPath}/misc/ids.nix"
  "${extPath}/misc/label.nix"
  "${extPath}/misc/meta.nix"
  "${extPath}/misc/nixpkgs.nix"
  "${extPath}/misc/version.nix"
  "${extPath}/programs/bash/bash-completion.nix"
  "${extPath}/programs/bash/bash.nix"
  "${extPath}/programs/bash/ls-colors.nix"
  "${extPath}/programs/environment.nix"
  "${extPath}/programs/less.nix"
  "${extPath}/programs/nano.nix"
  "${extPath}/security/ca.nix"
  "${extPath}/security/sudo.nix"
  "${extPath}/system/activation/activatable-system.nix"
  "${extPath}/system/activation/specialisation.nix"
  "${extPath}/system/boot/loader/efi.nix"
  "${extPath}/system/etc/etc-activation.nix"
  ./config/i18n.nix
  ./config/resolvconf.nix
  ./config/swap.nix
  ./config/sysctl.nix
  ./config/system-path.nix
  ./config/user-class.nix
  ./config/users-groups.nix
  ./misc/extra-arguments.nix
  ./misc/extra-ids.nix
  ./programs/services-mkdb.nix
  ./programs/shutdown.nix
  ./security/pam.nix
  ./security/wrappers/default.nix
  ./services/base-system.nix
  ./services/networking/dhcpcd.nix
  ./services/newsyslog.nix
  ./services/syslogd.nix
  ./services/ttys/getty.nix
  ./system/activation/activation-script.nix
  ./system/activation/bootspec.nix
  ./system/activation/top-level.nix
  ./system/boot/init/rc.nix
  ./system/boot/kernel.nix
  ./tasks/filesystems.nix
  ./tasks/network-interfaces.nix
  ./tasks/tempfiles
  ./virtualisation/vm-image.nix
]

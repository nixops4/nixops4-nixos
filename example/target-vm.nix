# Target VM NixOS configuration.
#
# This module defines the NixOS system that can be:
# 1. Deployed to via nixops4 (imported in deployment.nix)
# 2. Run standalone as a QEMU VM for testing
#
# Run the VM with:
#   nix run .#vm
{
  lib,
  pkgs,
  modulesPath,
  ...
}:
{
  imports = [
    # QEMU VM hardware configuration
    (modulesPath + "/profiles/qemu-guest.nix")
    # QEMU VM options (virtualisation.*, fileSystems, bootloader, etc.)
    (modulesPath + "/virtualisation/qemu-vm.nix")
  ];

  virtualisation.useBootLoader = true;

  system.switch.enable = true;

  # Not used; save a large copy operation
  nix.channel.enable = false;
  nix.registry = lib.mkForce { };

  nixpkgs.hostPlatform = "x86_64-linux";

  services.openssh.enable = true;
  services.openssh.settings.PermitRootLogin = "yes";
  networking.firewall.allowedTCPPorts = [ 22 ];

  users.users.root.initialPassword = "root";
  users.users.root.openssh.authorizedKeys.keyFiles = [ ./deployer.pub ];
  users.users.bossmang = {
    isNormalUser = true;
    group = "bossmang";
    extraGroups = [ "wheel" ];
    initialPassword = "bossmang";
    openssh.authorizedKeys.keyFiles = [ ./deployer.pub ];
  };
  users.groups.bossmang = { };

  security.sudo.execWheelOnly = true;
  security.sudo.wheelNeedsPassword = false;

  environment.systemPackages = [ pkgs.hello ];

  # VM-specific settings for interactive use
  virtualisation.forwardPorts = [
    {
      from = "host";
      host.port = 2222;
      guest.port = 22;
    }
  ];
}

# Test-specific deployment configuration.
#
# This module is loaded by nixops4.members.test (alongside deployment.nix).
# It configures the deployment for the integration test environment:
# - Sets hostPort/hostName for the test network
# - Adds nixos-test-base.nix to the NixOS configuration, which replicates the
#   qemu-vm and test-instrumentation config that the test framework provides to
#   test nodes, and must be preserved when the deployment takes over
{
  hostPort = 22;
  hostName = "target";

  imports = [
    # The test generates this file with runtime-discovered values
    ./deployment-test-generated.nix
  ];

  members.nixos.nixos.module =
    { modulesPath, ... }:
    {
      imports = [
        # Test framework base: qemu-vm options and test-instrumentation
        (modulesPath + "/../lib/testing/nixos-test-base.nix")
      ];

      # Test VMs don't have a bootloader
      boot.loader.grub.enable = false;
    };
}

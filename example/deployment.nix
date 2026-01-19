# NixOps4 deployment configuration.
#
# This module defines the deployment resources and is loaded by:
# - nixops4Deployments.default (for manual deployment via `nixops4 apply default`)
# - nixops4Deployments.test (for integration testing, with deployment-for-test.nix)
#
# The NixOS configuration (resources.nixos.nixos.module) imports target-vm.nix,
# which provides the base system configuration.
{
  config,
  inputs,
  lib,
  providers,
  withResourceProviderSystem,
  ...
}:
let
  inherit (lib) mkOption types;
in
{
  options = {
    hostPort = mkOption {
      type = types.int;
      default = 2222;
    };
    hostName = mkOption {
      type = types.str;
      default = "127.0.0.1";
    };
  };
  config = {
    providers.local = inputs.nixops4.modules.nixops4Provider.local;
    resources.hello = {
      type = providers.local.exec;
      inputs = {
        executable = withResourceProviderSystem ({ pkgs, ... }: lib.getExe pkgs.hello);
        args = [
          "--greeting"
          "Hallo wereld"
        ];
      };
    };
    resources.nixos = {
      type = providers.local.exec;
      imports = [
        inputs.nixops4-nixos.modules.nixops4Resource.nixos
      ];

      nixpkgs = inputs.nixpkgs;
      nixos.module =
        { pkgs, ... }:
        {
          imports = [ ./target-vm.nix ];

          # Deployment-specific configuration (not in target-vm.nix so the
          # integration test can verify these are installed by the deployment)
          environment.etc."greeting".text = config.resources.hello.outputs.stdout;
          environment.systemPackages = [ pkgs.hello ];
        };

      ssh.opts = "-i ./deployer-key -o Port=${toString config.hostPort}";
      ssh.host = config.hostName;
      ssh.hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAiszi43aOWWV7voNgQ1Ifa7LGKwGJfOuiLM1n42h2Y8";
    };
  };
}

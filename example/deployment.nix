# NixOps4 deployment configuration.
#
# This module defines the deployment components and is loaded by:
# - nixops4.members.default (for manual deployment via `nixops4 apply default`)
# - nixops4.members.test (for integration testing, with deployment-test.nix)
#
# The NixOS configuration (members.nixos.nixos.module) imports nixos-base.nix,
# which provides the base system configuration.
{
  config,
  inputs,
  lib,
  members,
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
    members.hello = {
      type = providers.local.exec;
      inputs = {
        executable = withResourceProviderSystem ({ pkgs, ... }: lib.getExe pkgs.hello);
        args = [
          "--greeting"
          "Hallo wereld"
        ];
      };
    };
    members.nixos = {
      type = providers.local.exec;
      imports = [
        inputs.nixops4-nixos.modules.nixops4Component.nixos
      ];

      nixpkgs = inputs.nixpkgs;
      nixos.module =
        { pkgs, ... }:
        {
          imports = [ ./nixos-base.nix ];

          # Deployment-specific configuration (not in nixos-base.nix so the
          # integration test can verify these are installed by the deployment)
          environment.etc."greeting".text = members.hello.outputs.stdout;
          environment.systemPackages = [ pkgs.hello ];
        };

      ssh.opts = "-i ./deployer-key -o Port=${toString config.hostPort}";
      ssh.host = config.hostName;
      ssh.hostPublicKey = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIAiszi43aOWWV7voNgQ1Ifa7LGKwGJfOuiLM1n42h2Y8";
    };
  };
}

# Flake module defining the project's flake outputs.
#
# Imported by flake.nix.
{ inputs, ... }:
{
  imports = [ inputs.nixops4.modules.flake.default ];

  perSystem =
    { pkgs, system, ... }:
    {
      # Development shell with nixops4
      # Enter with: nix develop
      devShells.default = pkgs.mkShell {
        packages = [
          inputs.nixops4.packages.${system}.default
        ];
      };

      # VM for interactive testing of the deployment target.
      # Run with: nix run .#vm
      packages.vm =
        (inputs.nixpkgs.lib.nixosSystem {
          inherit system;
          modules = [ ./nixos-base.nix ];
        }).config.system.build.vm;
    };

  nixops4Deployments.default =
    { ... }:
    {
      imports = [
        ./deployment.nix
      ];
      _module.args.inputs = inputs;
    };
  # Used by the integration test
  nixops4Deployments.test =
    { ... }:
    {
      imports = [
        ./deployment.nix
        ./deployment-test.nix
      ];
      _module.args.inputs = inputs;
    };
}

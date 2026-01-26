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

  nixops4 =
    { withResourceProviderSystem, ... }:
    {
      members.default = {
        _module.args.inputs = inputs;
        _module.args.withResourceProviderSystem = withResourceProviderSystem;
        imports = [
          ./deployment.nix
        ];
      };
      # Used by the integration test
      members.test = {
        _module.args.inputs = inputs;
        _module.args.withResourceProviderSystem = withResourceProviderSystem;
        imports = [
          ./deployment.nix
          ./deployment-test.nix
        ];
      };
    };
}

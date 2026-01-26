{
  description = "NixOS integration for NixOps4";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixops4-nixos.follows = ""; # self
    /**
      Provides `bash` and `ssh` client for the deployment script.
    */
    # Keep in sync with dev/flake.nix nixpkgs.
    # https://github.com/NixOS/nix/issues/7730#issuecomment-3663046220
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    {
      inherit
        (flake-parts.lib.mkFlake { inherit inputs; } {
          imports = [
            inputs.flake-parts.flakeModules.partitions
            inputs.flake-parts.flakeModules.modules
            ./main-module.nix
          ];
          systems = [
            "x86_64-linux"
            "aarch64-linux"
            "aarch64-darwin"
            "x86_64-darwin"
          ];
          partitions.dev.extraInputsFlake = ./dev;
          partitions.dev.module.imports = [ ./dev/flake-module.nix ];
          partitions.example.extraInputsFlake = ./dev;
          partitions.example.module.imports = [ ./example/flake-module.nix ];
          partitionedAttrs.devShells = "dev";
          partitionedAttrs.checks = "dev";
          partitionedAttrs.herculesCI = "dev";
          partitionedAttrs.packages = "example";
          partitionedAttrs.nixops4 = "example";
        })
        modules
        packages
        devShells
        checks
        /**
          Example configurations used in integration tests.
        */
        nixops4
        /**
          Continuous integration settings
        */
        herculesCI
        ;

      templates.default = {
        path = ./example;
        description = "NixOps4-NixOS deployment example";
      };
    };
}

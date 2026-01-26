{ inputs, ... }:
{
  imports = [
    inputs.git-hooks-nix.flakeModule
    inputs.hercules-ci-effects.flakeModule
  ];
  herculesCI.ciSystems = [ "x86_64-linux" ];
  hercules-ci.flake-update = {
    enable = true;
    baseMerge.enable = true;
    when = {
      hour = [ 8 ];
      dayOfMonth = [ 3 ];
    };
  };
  perSystem =
    {
      config,
      inputs',
      pkgs,
      ...
    }:
    {
      checks = {
        default = pkgs.callPackage ../test/default/nixosTest.nix {
          nixops4-flake-in-a-bottle = inputs'.nixops4.packages.flake-in-a-bottle;
          inherit inputs;
        };
      };
      devShells.default = pkgs.mkShellNoCC {
        nativeBuildInputs = [
          pkgs.nixfmt
          inputs'.nixops4.packages.default
        ];
        shellHook = ''
          ${config.pre-commit.settings.shellHook}
        '';
      };
      pre-commit.settings.hooks.nixfmt.enable = true;
    };
}

{
  flake-parts-lib,
  self,
  withSystem,
  ...
}:
{
  flake.modules = {
    nixops4Component = {
      nixos = flake-parts-lib.importApply ./modules/nixops4Resource/nixos.nix {
        inherit self withSystem;
      };
    };
    nixosTest = {
      static = ./modules/nixosTest/static.nix;
    };
    nixos = {
      apply = ./modules/nixos/apply/nixos-apply.nix;
    };
  };
}

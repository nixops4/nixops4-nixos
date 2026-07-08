thisFlake:
args@{
  config,
  lib,
  ...
}:
let
  inherit (lib) mkOption types;
  common = (import ./common.nix thisFlake) args;
in
{
  imports = [ common ];

  options = {
    nixos.module = mkOption {
      type = types.deferredModule;
    };
    nixos.configuration = mkOption {
      type = types.raw;
      readOnly = true;
    };
    nixos.specialArgs = mkOption {
      type = types.raw;
      default = { };
    };
  };

  config = {
    nixos.configuration = config.nixpkgs.lib.nixosSystem {
      modules = [
        config.nixos.module
        thisFlake.self.modules.nixos.apply
      ];
      specialArgs = config.nixos.specialArgs;
    };

    _toplevel = config.nixos.configuration.config.system.build.toplevel;
  };
}

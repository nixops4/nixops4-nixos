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
    darwin.module = mkOption {
      type = types.deferredModule;
    };
    darwin.configuration = mkOption {
      type = types.raw;
      readOnly = true;
    };
    darwin.specialArgs = mkOption {
      type = types.raw;
      default = { };
    };
  };

  config = {
    nixos.configuration = config.nixpkgs.lib.nixosSystem {
      modules = [
        config.darwin.module
        #thisFlake.self.modules.nixos.apply #TODO: Add darwin-rebuild apply support
      ];
      specialArgs = config.darwin.specialArgs;
    };

    _toplevel = config.darwin.configuration.config.system.build.toplevel;
  };
}

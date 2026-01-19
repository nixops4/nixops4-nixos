{
  description = "NixOps4-NixOS deployment example";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixops4-nixos.url = "github:nixops4/nixops4-nixos";
    nixops4-nixos.inputs.flake-parts.follows = "flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixops4.url = "github:nixops4/nixops4";
    nixops4.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ./flake-module.nix ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
}

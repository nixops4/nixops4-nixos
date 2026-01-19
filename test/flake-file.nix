# This is NOT a flake. It is copied to flake.nix by the integration test.
# The test provides inputs via --override-input flags during nix flake lock.
{
  description = "NixOps4-NixOS integration tests";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixops4-nixos.url = ../.;
    nixops4-nixos.inputs.flake-parts.follows = "flake-parts";
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixops4.url = "github:nixops4/nixops4";
    nixops4.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    inputs@{ flake-parts, ... }:
    flake-parts.lib.mkFlake { inherit inputs; } {
      imports = [ ../example/flake-module.nix ];
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
    };
}

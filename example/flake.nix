{
  description = "NixOps4 / NixOS deployment example";

  inputs = {
    flake-parts.url = "github:hercules-ci/flake-parts";
    nixopus.url = "github:nixops4/nixopus";
    nixopus.inputs.flake-parts.follows = "flake-parts";
    nixopus.inputs.nixpkgs.follows = "nixpkgs";
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

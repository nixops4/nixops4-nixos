{
  description = "dependencies only";
  inputs = {
    # Keep in sync with the root flake's nixpkgs.
    # https://github.com/NixOS/nix/issues/7730#issuecomment-3663046220
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    nixops4.url = "github:nixops4/nixops4";
    nixops4.inputs.nixpkgs.follows = "nixpkgs";
    git-hooks-nix.url = "github:cachix/git-hooks.nix";
    git-hooks-nix.inputs.nixpkgs.follows = "nixpkgs";
    hercules-ci-effects.url = "github:hercules-ci/hercules-ci-effects";
    hercules-ci-effects.inputs.nixpkgs.follows = "nixpkgs";
  };
  outputs = { ... }: { };
}

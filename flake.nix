{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixpkgs-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    nimble2nix.url = "github:bandithedoge/nimble2nix";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nimble2nix,
    ...
  } @ inputs:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = import nixpkgs {
        inherit system;
        overlays = [nimble2nix.overlay];
      };
    in {
      # This function is defined at:
      # https://github.com/bandithedoge/nimble2nix/blob/main/buildNimblePackage.nix
      defaultPackage = pkgs.buildNimblePackage {
        # Name and version of your package
        pname = "fedi";
        version = "0.1";

        # Where your package is located
        # Must contain `nimble2nix.json` generated by running `nimble2nix`
        src = ./.;

        # Uncomment the following line if your `nimble2nix.json` has a different name:
        # deps = ./my-custom-deps.json;

        # Extra libraries required by Nim packages or build scripts
        buildInputs = with pkgs; [SDL2];
        nativeBuildInputs = with pkgs; [neofetch];
      };
    });
}
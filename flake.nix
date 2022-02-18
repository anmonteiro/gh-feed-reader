{
  description = "Piaf Nix Flake";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "/Users/anmonteiro/projects/nix-overlays";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
      in
      rec {
        packages = pkgs.callPackage ./nix { inherit pkgs; };
        defaultPackage = packages.native;
        devShell = import ./shell.nix { inherit pkgs; };
      });
}

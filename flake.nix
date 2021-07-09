{
  description = "Piaf Nix Flake";

  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "/Users/anmonteiro/projects/nix-overlays";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages."${system}";
      in
      {
        devShell = import ./shell.nix { inherit pkgs; };
        devShells.melange = import ./bsb-shell.nix { inherit pkgs; };
      });
}
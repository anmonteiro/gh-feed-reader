{
  description = "Piaf Nix Flake";

  inputs.nix-filter.url = "github:numtide/nix-filter";
  inputs.flake-utils.url = "github:numtide/flake-utils";
  inputs.nixpkgs.url = "github:nix-ocaml/nix-overlays";
  inputs.melange.url = "github:melange-re/melange";
  inputs.melange.inputs.nixpkgs.follows = "nixpkgs";

  outputs = { self, nixpkgs, flake-utils, nix-filter, melange }:
    flake-utils.lib.eachDefaultSystem (system:
      let
        pkgs = nixpkgs.legacyPackages.${system}.extend (self: super: {
          ocamlPackages = super.ocaml-ng.ocamlPackages_5_0.overrideScope' (oself: osuper: {
            piaf = osuper.piaf.overrideAttrs (_: {
              src = super.fetchFromGitHub {
                owner = "anmonteiro";
                repo = "piaf";
                rev = "e741d9f6f90968bc72661583bfb49a7712442634";
                sha256 = "sha256-cmhlUnzz8IvF9VS4DOXTXIbua7Wz0fAIdJAFWICXRQY=";
              };
            });
          });
        });
      in

      rec {
        packages = {
          native = pkgs.callPackage ./nix {
            nix-filter = nix-filter.lib;
          };

          musl64 =
            let pkgs = pkgs.pkgsCross.musl64;
            in
            pkgs.callPackage ./nix {
              static = true;
              nix-filter = nix-filter.lib;
              ocamlPackages = pkgs.ocamlPackages;
            };
        };
        defaultPackage = packages.native;
        devShells.default = pkgs.callPackage ./nix/shell.nix {
          inherit packages;
        };
        devShells.melange = pkgs.callPackage ./nix/melange-shell.nix {
          melange-flake = melange;
        };
      });
}

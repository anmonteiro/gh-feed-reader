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
          ocamlPackages = super.ocaml-ng.ocamlPackages_5_0.overrideScope' (oself: osuper: { });
        });
      in

      rec {
        packages = {
          native = pkgs.callPackage ./nix {
            nix-filter = nix-filter.lib;
          };

          musl64 =
            let
              pkgs' = pkgs.pkgsCross.musl64;
            in
            pkgs'.lib.callPackageWith pkgs' ./nix {
              static = true;
              nix-filter = nix-filter.lib;
            };

          melange-frontend =
            let
              opkgs = pkgs.appendOverlays [
                (self: super: {
                  ocamlPackages = self.ocaml-ng.ocamlPackages_4_14.overrideScope' (oself: osuper: { });
                })
                melange.overlays.default
                (self: super: {
                  ocamlPackages = super.ocamlPackages.overrideScope' (oself: osuper: {
                    dune_3 = osuper.dune_3.overrideAttrs (_: {
                      src = super.fetchFromGitHub {
                        owner = "ocaml";
                        repo = "dune";
                        rev = "32a75099940859c694dd5b185f22c4931081b4ef";
                        hash = "sha256-iFGXY5R5LwOCuVPwZk9jsfCMaKnqC1JT9j31pY0fRc8=";
                      };
                    });
                  });
                })
              ];
            in
            with opkgs; stdenv.mkDerivation {
              name = "melange-frontend";
              src = ./.;
              nativeBuildInputs =
                with opkgs; [ yarn ocamlPackages.melange exa ] ++ (
                  with opkgs.ocamlPackages; [ ocaml dune findlib ]
                );
              buildInputs = with opkgs.ocamlPackages; [ reason ];
              NODE_OPTIONS = "--openssl-legacy-provider";
              buildPhase = ''
                # https://github.com/yarnpkg/yarn/issues/2629#issuecomment-685088015
                yarn install --frozen-lockfile --check-files --cache-folder .ycache && rm -rf .ycache

                dune build @melange --display=short
                exa -T ./_build/default/src/dist
                yarn build-cra
              '';

              installPhase = ''
                cp -r build $out
              '';
            };
        };
        defaultPackage = packages.native;
        devShells.default = pkgs.callPackage ./nix/shell.nix {
          inherit packages;
        };
        devShells.melange = pkgs.callPackage ./nix/melange-shell.nix {
          inherit (packages) melange-frontend;
        };
      });
}

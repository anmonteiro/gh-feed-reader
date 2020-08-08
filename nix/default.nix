{ ocamlVersion ? "4_11", sources ? import ./sources.nix { inherit ocamlVersion; } }:

let
  inherit (sources) pkgs overlays;
  inherit (pkgs) lib callPackage;
in
  {
    native = callPackage ./generic.nix {
      inherit (lib) filterGitSource;
    };

    musl64 =
      let pkgs = (import "${overlays}/static" {
        inherit ocamlVersion;
        pkgsPath = "${overlays}/sources.nix";
      });
      in
      pkgs.callPackage ./generic.nix {
        static = true;
        inherit (lib) filterGitSource;
        ocamlPackages = pkgs.ocaml-ng."ocamlPackages_${ocamlVersion}";
      };
  }

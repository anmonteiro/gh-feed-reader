{ ocamlVersion ? "4_12" }:

let
  lock = builtins.fromJSON (builtins.readFile ./../flake.lock);
  src = fetchGit {
    url = with lock.nodes.nixpkgs.locked;"https://github.com/${owner}/${repo}";
    inherit (lock.nodes.nixpkgs.locked) rev;
    # inherit (lock.nodes.nixpkgs.original) ref;
  };
  pkgs = import "${src}/boot.nix" {
    overlays = [
      (import src)
      (self: super: {
        ocamlPackages = super.ocaml-ng."ocamlPackages_${ocamlVersion}";

        pkgsCross.musl64 = super.pkgsCross.musl64 // {
          ocamlPackages = super.pkgsCross.musl64.ocaml-ng."ocamlPackages_${ocamlVersion}";
        };
      })
    ];
  };

  inherit (pkgs) lib stdenv fetchTarball ocamlPackages;

in

(pkgs.callPackage ./. { }).musl64

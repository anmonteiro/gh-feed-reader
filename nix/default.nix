{ pkgsPath ? <nixpkgs> }:

let
  overlays = builtins.fetchTarball {
    url = https://github.com/anmonteiro/nix-overlays/archive/5f01eb1.tar.gz;
    sha256 = "16yp2y2qxpxx5wwyj9n1ihzyncj621mdmy0g6l33fpnz9ag8qh21";
  };
  pkgs = import pkgsPath { overlays = [ (import overlays) ]; };

  gitignoreSrc = pkgs.fetchFromGitHub {
    owner = "hercules-ci";
    repo = "gitignore";
    rev = "7415c4f";
    sha256 = "1zd1ylgkndbb5szji32ivfhwh04mr1sbgrnvbrqpmfb67g2g3r9i";
  };
  inherit (import gitignoreSrc { inherit (pkgs) lib; }) gitignoreSource;
in
  {
    native = pkgs.callPackage ./generic.nix {
      inherit gitignoreSource;
    };

    musl64 =
      let pkgs = (import "${overlays}/static" {
        inherit pkgsPath;
        ocamlVersion = "4_09";
      });
      in
      pkgs.callPackage ./generic.nix {
        static = true;
        inherit gitignoreSource;
        ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_09;
      };
  }

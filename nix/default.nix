{ pkgsPath ? <nixpkgs> }:

let
  overlays = builtins.fetchTarball {
    url = https://github.com/anmonteiro/nix-overlays/archive/6c6f3e1.tar.gz;
    sha256 = "0ih9yf4dnp72g3rjqxak16mgw073ca62f0vbx61dwvhxl371vl4q";
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

{ pkgsPath ? <nixpkgs> }:

let
  pkgs = import pkgsPath {};

  gitignoreSrc = pkgs.fetchFromGitHub {
    owner = "hercules-ci";
    repo = "gitignore";
    rev = "7415c4f";
    sha256 = "1zd1ylgkndbb5szji32ivfhwh04mr1sbgrnvbrqpmfb67g2g3r9i";
  };
  inherit (import gitignoreSrc { inherit (pkgs) lib; }) gitignoreSource;

  overlays = /home/anmonteiro/projects/nix-overlays;
  # builtins.fetchTarball {
    # url = https://github.com/anmonteiro/nix-overlays/archive/44b0ff7.tar.gz;
    # sha256 = "18gzn7zzqag2lzwlvz28n30kibqgpy1vwsdy3jlnkbcf3xk5icjx";
  # };

  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_09.overrideScope'
    (pkgs.callPackage "${overlays}/ocaml" {});
in
  {
    native = pkgs.callPackage ./generic.nix {
      inherit ocamlPackages gitignoreSource;
    };

    musl64 =
      let pkgs = import "${overlays}/static.nix" {
        inherit pkgsPath;
        ocamlVersion = "4_09";
      };
      in
      pkgs.callPackage ./generic.nix {
        static = true;
        inherit gitignoreSource;
        ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_09;
      };
  }

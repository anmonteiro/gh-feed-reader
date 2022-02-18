{ pkgs }:

let
  inherit (pkgs) lib callPackage pkgsCross;
in
{
  native = callPackage ./generic.nix {
    inherit (lib) filterGitSource;
  };

  musl64 =
    let pkgs = pkgsCross.musl64;
    in
    pkgs.callPackage ./generic.nix {
      static = true;
      inherit (lib) filterGitSource;
      ocamlPackages = pkgs.ocamlPackages;
    };
}

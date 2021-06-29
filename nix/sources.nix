{ ocamlVersion ? "4_11" }:

let
  overlays =
    builtins.fetchTarball
      https://github.com/anmonteiro/nix-overlays/archive/aca1d60.tar.gz;

in {
  inherit overlays;
  pkgs = import "${overlays}/sources.nix" {};
}


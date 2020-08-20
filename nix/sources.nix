{ ocamlVersion ? "4_11" }:

let
  overlays =
    builtins.fetchTarball
      https://github.com/anmonteiro/nix-overlays/archive/f8aa307.tar.gz;

in {
  inherit overlays;
  pkgs = import "${overlays}/sources.nix" {};
}


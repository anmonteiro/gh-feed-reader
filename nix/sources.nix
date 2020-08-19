{ ocamlVersion ? "4_11" }:

let
  overlays =
    builtins.fetchTarball
      https://github.com/anmonteiro/nix-overlays/archive/fce4fbe.tar.gz;

in {
  inherit overlays;
  pkgs = import "${overlays}/sources.nix" {};
}


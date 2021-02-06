{ ocamlVersion ? "4_11" }:
let
  overlays =
    builtins.fetchTarball
      https://github.com/anmonteiro/nix-overlays/archive/8c8edf2.tar.gz;

in
{
  inherit overlays;
  pkgs = import "${overlays}/sources.nix" { };
}

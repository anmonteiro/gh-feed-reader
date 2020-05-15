let
  sources = (import ./nix/sources.nix {});
  pkgs = sources.pkgs;
  inherit (pkgs) lib;
in
  with pkgs;

  mkShell {
    inputsFrom = [ (import ./nix { inherit sources; }).native ];
    buildInputs = with ocamlPackages; [ merlin ocamlformat utop ];
  }

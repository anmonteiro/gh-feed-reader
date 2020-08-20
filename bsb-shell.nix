
let
  sources = (import ./nix/sources.nix {});
  pkgs = sources.pkgs;
  ocamlPackages = pkgs.ocamlPackages-bs;
in
  with pkgs;

  mkShell {
    buildInputs = with ocamlPackages; [
      bucklescript-experimental
      dune_2
      ocaml
      ocaml-syntax-shims

      nodejs
      yarn
      merlin
      reason
      python3
      ocamlformat
    ];

    BSB_PATH="${bucklescript-experimental}";
  }


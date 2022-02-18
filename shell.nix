{ pkgs }:

let
  inherit (pkgs) lib mkShell ocaml-ng;
  ocamlPackages = ocaml-ng.ocamlPackages_4_12;

in

mkShell {
  OCAMLRUNPARAM = "b";
  buildInputs = (with ocamlPackages; [ ocaml findlib easy-format dune cmdliner utop ]);
  # utop
}

{ pkgs }:

with pkgs;

mkShell {
  buildInputs = with ocamlPackages; [
    nodejs_latest
    yarn
    merlin
    melange
    reason
    python3
    # ocamlformat
    dune
    ocaml
    findlib
  ];

  BSB_PATH = "${bucklescript-experimental}";
  shellHook = ''
    PATH=$BSB_PATH/bin:$PATH
  '';
}

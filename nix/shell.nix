{ pkgs, packages }:

with pkgs;

mkShell {
  buildInputs = with ocamlPackages; [
    nodejs_latest
    yarn
    merlin
    # melange
    reason
    python3
    ocamlformat
    dune
    ocaml
    findlib
    dot-merlin-reader
    # merlin
  ];

  inputsFrom = [ packages.native ];

  BSB_PATH = "/Users/anmonteiro/projects/melange";
  shellHook = ''
    PATH=$BSB_PATH/bin:$PATH
  '';
}

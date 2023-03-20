{ melange-frontend, mkShell }:

mkShell {
  inputsFrom = [ melange-frontend ];
  buildInputs = [
    merlin
    ocamlformat
    reason
  ];
}

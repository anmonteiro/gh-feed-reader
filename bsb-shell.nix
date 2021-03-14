let
  sources = (import ./nix/sources.nix { });
  pkgs = sources.pkgs;
  ocamlPackages = pkgs.ocamlPackages-bs;
in
with pkgs;

mkShell {
  buildInputs = with ocamlPackages; [
    # bs-platform
    nodejs
    yarn
    merlin
    reason
    python3
    # ocamlformat
    ocaml-syntax-shims
    pkgs.ocaml-ng.ocamlPackages_4_11.dune_2
    ocaml
    findlib
  ];

  BSB_PATH = "${bucklescript-experimental}";
  shellHook = ''
    PATH=$BSB_PATH/bin:$PATH
  '';
}

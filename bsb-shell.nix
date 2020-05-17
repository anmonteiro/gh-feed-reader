
let
  sources = (import ./nix/sources.nix {});
  pkgs = sources.pkgs;
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_06;
in
  with pkgs;

  mkShell {
    buildInputs = with ocamlPackages; [
      bs-platform
      nodejs
      yarn
      merlin
      reason
      python3
      ocamlformat
    ];

    BSB_PATH="${bs-platform}";
  }


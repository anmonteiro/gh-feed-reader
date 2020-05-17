
let
  sources = (import ./nix/sources.nix {});
  pkgs = sources.pkgs;
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_06;
in
  with pkgs;

  mkShell {
    buildInputs = with ocamlPackages; [
      which
      bs-platform
      nodejs
      yarn
      merlin
      reason
      python3
      ocamlformat
    ];

    BSB_PATH="${bs-platform}";

    shellHook = ''
      yarn install
      mkdir -p node_modules/.bin
      ln -sfn ${bs-platform} node_modules/bs-platform
      ln -sfn ${bs-platform}/bin/* ./node_modules/.bin
      echo "bs-platform linked to $(pwd)/node_modules/bs-platform"
    '';
  }


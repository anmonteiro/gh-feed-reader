
let
  pkgs = import ./nix/sources.nix {};
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_06;
in
  with pkgs;

  mkShell {
    buildInputs = with ocamlPackages; [ bs-platform nodejs yarn merlin reason python3 ocamlformat ];

    shellHook = ''
      yarn install
      mkdir -p node_modules/.bin
      ln -sfn ${bs-platform} node_modules/bs-platform
      ln -sfn ${bs-platform}/bin/* ./node_modules/.bin
      echo "bs-platform linked to $(pwd)/node_modules/bs-platform"
    '';
  }


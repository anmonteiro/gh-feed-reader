
let
  overlays = builtins.fetchTarball {
    url = "https://github.com/anmonteiro/nix-overlays/archive/d580433.tar.gz";
    sha256 = "14yzzqvxnjhmxrkz4j0340dwpdy01wazq6yf5i5xblds522n63ih";
  };

  pkgs = import <nixpkgs> { overlays = [ (import overlays) ]; };
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_06;
in

with pkgs;

mkShell {
    buildInputs = with ocamlPackages; [ bs-platform nodejs yarn merlin reason ];

    shellHook = ''
      yarn install
      mkdir -p node_modules/.bin
      ln -sfn ${bs-platform} node_modules/bs-platform
      ln -sfn ${bs-platform}/bin/* ./node_modules/.bin
      echo "bs-platform linked to $(pwd)/node_modules/bs-platform"
    '';
}

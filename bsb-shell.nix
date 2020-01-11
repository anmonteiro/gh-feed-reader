
let
  overlays = builtins.fetchTarball {
    url = "https://github.com/anmonteiro/nix-overlays/archive/37b275a.tar.gz";
    sha256 = "02vcx6kph9m526c63xk87w4m98vpsz28d0164ca828jc96klssfh";
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

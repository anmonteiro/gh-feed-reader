{ ocamlVersion }:

let
  overlays = builtins.fetchTarball {
    url = https://github.com/anmonteiro/nix-overlays/archive/186e65d.tar.gz;
    sha256 = "1bf2idjzryb01h1z75shhjanpqflm7dzbcv0b95rb18rvg7czyi4";
  };

in

  {
    inherit overlays;
    pkgs = import "${overlays}/sources.nix" {
      overlays = [
        (import overlays)
        (self: super: {
          ocamlPackages = super.ocaml-ng."ocamlPackages_${ocamlVersion}".overrideScope'
              (super.callPackage "${overlays}/ocaml" {});
        })
      ];
    };
  }

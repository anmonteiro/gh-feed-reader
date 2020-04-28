{ ocamlVersion ? "4_10" }:

let
  overlays = builtins.fetchTarball {
    url = https://github.com/anmonteiro/nix-overlays/archive/b39baaf.tar.gz;
    sha256 = "1j9j3fzbi6r5c2y3bmf8yr6wwbs9a5r64v6n6w6r5rbj7n9cff29";
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

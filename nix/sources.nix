{ ocamlVersion ? "4_10" }:

let
  overlays = builtins.fetchTarball {
    url = https://github.com/anmonteiro/nix-overlays/archive/9fd3b18.tar.gz;
    sha256 = "1dfjykaz3pv97fn7q3pxg5acbl7ib69i7aq65l5h55zflkxpwfii";
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

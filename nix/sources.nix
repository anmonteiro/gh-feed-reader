{ ocamlVersion }:

let
  overlays = /home/anmonteiro/projects/nix-overlays;
  # overlays = builtins.fetchTarball {
    # url = https://github.com/anmonteiro/nix-overlays/archive/94de6452.tar.gz;
    # sha256 = "1hlwlclhrm60zz90mv55mlacbfd4hddrf04sk6yl6yr9k2clx9sl";
  # };

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

{ pkgs, melange-flake }:

let
  opkgs = pkgs.appendOverlays [
    (self: super: {
      ocamlPackages = self.ocaml-ng.ocamlPackages_4_14.overrideScope' (oself: osuper: {
        dune_3 = osuper.dune_3.overrideAttrs (_: {
          src = super.fetchFromGitHub {
            owner = "ocaml";
            repo = "dune";
            rev = "a0dd51512f269d7c18f0c6216ab66d3ab7368da2";
            hash = "sha256-z9D4lpQwrsJWoPECcAupMVLf23tM+IrwmzOB8F1i8Qk=";
          };
        });
      });
    })
    melange-flake.overlays.default
  ];

in

with opkgs;
mkShell {
  buildInputs = with ocamlPackages; [
    nodejs_latest
    yarn
    merlin
    ocaml-lsp
    melange
    reason
    ocamlformat
    dune
    ocaml
    findlib
  ];
}

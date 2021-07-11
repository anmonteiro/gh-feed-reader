let
  sources = (import ./nix/sources.nix {});
  pkgs = sources.pkgs;
  ocamlPackages = pkgs.ocaml-ng.ocamlPackages_4_12;
in
  with pkgs;

  mkShell {
    buildInputs = with ocamlPackages; [
      #bs-platform
      melange
      dune
      nodejs
      yarn
      merlin
      reason
      python3
      ocamlformat
    ] ++ lib.optionals stdenv.isDarwin (
      with darwin.apple_sdk.frameworks; [
        Cocoa
        CoreServices
      ]
    );

    BSB_PATH = "${ocamlPackages.melange}";
  }

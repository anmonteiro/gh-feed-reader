let
  sources = (import ./nix/sources.nix {});
  pkgs = sources.pkgs;
  inherit (pkgs) lib;
in
  with pkgs;

  mkShell {
    inputsFrom = [ (import ./nix { inherit sources; }).native ];
    buildInputs = with ocamlPackages;
      [
        merlin
        ocamlformat
        utop
        melange
        dune
        nodejs
        yarn
        reason
        python3
      ] ++ lib.optionals stdenv.isDarwin (
        with darwin.apple_sdk.frameworks; [
          Cocoa
          CoreServices
        ]
      );

    BSB_PATH = "${ocamlPackages.melange}";
  }

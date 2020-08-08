{ filterGitSource, stdenv, openssl, ocamlPackages, static ? false }:

stdenv.mkDerivation {
  name = "gh-feed-lambda";
  version = "dev";

  src = filterGitSource {
    src = ./..;
    dirs = [ "lambda" "shared" ];
    files = [ "dune-project" ];
  };

  nativeBuildInputs = with ocamlPackages; [dune_2 ocaml findlib];

  buildPhase = ''
    echo "running ${if static then "static" else "release"} build"
    dune build lambda/lambda.exe --display=short --profile=${if static then "static" else "release"}
  '';
  installPhase = ''
    mkdir -p $out/bin
    mv _build/default/lambda/lambda.exe $out/bin/lambda.exe
  '';

  buildInputs = with ocamlPackages; [
    piaf
    lambdasoup
    ppx_deriving_yojson
    syndic
    lwt
    fmt
    now
  ];

  doCheck = false;
}

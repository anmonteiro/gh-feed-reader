{ pkgs, stdenv, ocamlPackages, gitignoreSource, static ? false }:

stdenv.mkDerivation {
  name = "gh-feed-lambda";
  version = "dev";

  srcs = [ ../lambda ../shared ../dune-project ];

  nativeBuildInputs = with ocamlPackages; [dune_2 ocaml findlib];

  unpackPhase = ''
    for src in $srcs; do
      dest=$(stripHash $src)

      if [[ -d $src ]]; then
        mkdir $dest
        cp -R $src/* "./$dest"
      else
        cp -R $src "./$dest"
      fi
    done
  '';

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
    lwt4
    fmt
    now
  ];

  doCheck = false;
}

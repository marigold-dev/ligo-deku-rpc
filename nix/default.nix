{
  lib,
  stdenv,
  nix-filter,
  ocaml,
  findlib,
  dune,
  eio,
  eio_main,
  eio_linux,
  piaf,
  routes,
  logs,
  fmt,
  yojson,
  mirage-crypto,
  tunac,
  ligo,
}:
stdenv.mkDerivation {
  name = "ligo-deku-rpc";

  src = with nix-filter.lib;
    filter {
      root = ../.;
      include = [
        "src/bin"
        "src/lib"
        "dune-project"
        "ligo_deku_rpc.opam"
        ".ocamlformat"
      ];
    };

  nativeBuildInputs = [dune ocaml findlib];

  buildInputs = [
    eio_main
    eio
    eio_linux
    piaf
    routes
    logs
    fmt
    yojson
    mirage-crypto
  ];

  buildPhase = ''
    dune build --profile=release ./src/bin/main.exe
  '';

  installPhase = ''
    mkdir -p $out/bin
    cp _build/default/src/bin/main.exe $out/bin/ligo-deku-rpc
  '';
}

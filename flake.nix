{
  description = "RPC server for LIGO to WASM";

  nixConfig = {
    extra-substituters = "https://anmonteiro.nix-cache.workers.dev";
    extra-trusted-public-keys = "ocaml.nix-cache.com-1:/xI2h2+56rwFfKyyFVbkJSeGqSIYMC/Je+7XXqGKDIY=";
  };

  inputs = {
    nixpkgs.url = "github:nix-ocaml/nix-overlays";
    nix-filter.url = "github:numtide/nix-filter";
    flake-utils.url = "github:numtide/flake-utils";
    nix2container.url = "github:nlewo/nix2container";
    nix2container.inputs = {
      nixpkgs.follows = "nixpkgs";
      flake-utils.follows = "flake-utils";
    };

    tezos.url = "github:marigold-dev/tezos-nix";
    tezos.inputs = {
      nixpkgs.follows = "nixpkgs";
    };

    tuna.url = "github:marigold-dev/tuna/ulrikstrid--better-tunac-package";
    tuna.inputs = {
      nixpkgs.follows = "nixpkgs";
      tezos.follows = "tezos";
    };

    ligo.url = "gitlab:ligolang/ligo";
    ligo.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs = {
    self,
    nixpkgs,
    flake-utils,
    nix-filter,
    nix2container,
    tezos,
    tuna,
    ligo,
  }:
    flake-utils.lib.eachDefaultSystem (system: let
      pkgs = nixpkgs.legacyPackages.${system}.appendOverlays [
        tezos.overlays.default
        (final: prev: {
          ocamlPackages = prev.ocaml-ng.ocamlPackages_5_00.overrideScope' (oself: osuper: {
            routes = osuper.routes.overrideAttrs (_: {
              version = "2.0.0-dev";
              src = final.fetchFromGitHub {
                owner = "anuragsoni";
                repo = "routes";
                rev = "3cf574ebed7b60366fa8ddcbe8f7c2c5f83c678f";
                sha256 = "sha256-Q7ZWcCIiA0K+m8DvnXBhQlVKFmMly1D+Fz+hmLhE2WU=";
              };
            });
            bls12-381 = osuper.bls12-381.overrideAttrs (_: {
              doCheck = false;
            });

            tezos-crypto = osuper.tezos-crypto.overrideAttrs (_: {
              postPatch = ''
                substituteInPlace "src/lib_crypto/helpers.ml" --replace \
                  "let hash = H.seeded_hash" \
                  "let hash = H.seeded_hash let seeded_hash = H.seeded_hash"
              '';
            });

            tezos-stdlib = osuper.tezos-stdlib.overrideAttrs (_: {
              postPatch = ''
                substituteInPlace "src/lib_stdlib/hash_queue.mli" --replace \
                  "val filter : t -> (K.t -> V.t -> bool) -> unit" \
                  ""
              '';
            });

            ringo = osuper.ringo.overrideAttrs (_: {
              src = builtins.fetchurl {
                url =
                  https://gitlab.com/nomadic-labs/ringo/-/archive/5514a34ccafdea498e4b018fb141217c1bf43da9/ringo-5514a34ccafdea498e4b018fb141217c1bf43da9.tar.gz;
                sha256 = "1qadbvmqirn1scc4r4lwzqs4rrwmp1vnzhczy9pipfnf9bb9c0j7";
              };
            });
          });
        })
      ];
      nix2containerPkgs = nix2container.packages.${system};
    in {
      packages = {
        default = pkgs.ocamlPackages.callPackage ./nix {
          inherit nix-filter;
          tunac = tuna.packages.${system}.tuna;
          ligo = ligo.packages.${system}.ligoLight;
        };
        docker = pkgs.callPackage ./nix/docker.nix {
          inherit nix2containerPkgs;
          ligo-deku-rpc = self.packages.${system}.default;
          tunac = tuna.packages.${system}.tuna;
          ligo = ligo.packages.${system}.ligoLight;
        };
      };

      devShells.default = pkgs.mkShell rec {
        nativeBuildInputs = with pkgs.ocamlPackages; [
          pkgs.alejandra
          ocamlformat
          ocaml-lsp
          dune
          ocaml

          tuna.packages.${system}.tuna
          ligo.packages.${system}.ligoLight
        ];
        propagatedBuildInputs = with pkgs.ocamlPackages; [
          findlib
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
      };
    });
}

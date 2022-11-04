{
  pkgs,
  nix2containerPkgs,
  ligo-deku-rpc,
  tunac,
  ligoLight,
}:
nix2containerPkgs.nix2container.buildImage rec {
  name = "ghcr.io/marigold-dev/ligo-deku-rpc";
  tag = "latest";

  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = [
      tunac
      ligoLight
      pkgs.coreutils
      pkgs.dockerTools.fakeNss
      pkgs.bash
      pkgs.unixtools.netstat
    ];
    pathsToLink = ["/bin"];
  };

  config = {
    Entrypoint = ["${ligo-deku-rpc}/bin/ligo-deku-rpc"];
    Cmd = ["-p" "8080"];
    author = "Ulrik Strid";
    architecture = "amd64";
    os = "linux";
    ExposedPorts = {
      "8080/tcp" = {};
    };

    Env = [
      "SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
      "NIX_SSL_CERT_FILE=${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt"
    ];
    WorkingDir = "/app";
  };
}

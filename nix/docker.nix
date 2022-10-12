{
  pkgs,
  ligo-deku-rpc,
  tunac,
  ligo,
}:
pkgs.dockerTools.buildImage rec {
  name = "ligo-deku-rpc";

  copyToRoot = pkgs.buildEnv {
    name = "image-root";
    paths = [
      tunac
      ligo
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

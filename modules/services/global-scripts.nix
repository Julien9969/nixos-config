{ config, lib, pkgs, ... }:
let
  speedtest-docker = pkgs.writeShellScriptBin "speedtest-docker" ''
    #!/usr/bin/env bash
    docker run --rm -it gists/speedtest-cli
  '';
in {
  environment.systemPackages = [
    speedtest-docker
  ];
}
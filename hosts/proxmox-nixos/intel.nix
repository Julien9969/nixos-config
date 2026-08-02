{ config, lib, pkgs, modulesPath, ... }:

{
    hardware.graphics = {
        enable = true;
        extraPackages = with pkgs; [
            intel-media-driver
            libva-utils
            intel-compute-runtime
            vpl-gpu-rt
            libvpl
        ];
    };
}
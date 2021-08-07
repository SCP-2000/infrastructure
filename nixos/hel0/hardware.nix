{ config, lib, pkgs, ... }:
let
  mountDevice = "/dev/disk/by-partuuid/d59a13b5-3e04-4d42-be80-1f1377d1e43c";
  mountOptions = [
    "relatime"
    "compress-force=zstd"
    "space_cache=v2"
  ];
in
{
  boot.initrd.availableKernelModules = [ "ahci" "sd_mod" ];
  boot.kernelModules = [ "kvm-amd" ];

  boot.loader.grub = {
    enable = true;
    devices = [ "/dev/disk/by-id/wwn-0x50000397fc5003aa" "/dev/disk/by-id/wwn-0x500003981ba001ae" ];
  };

  fileSystems."/" = {
    fsType = "tmpfs";
    options = [ "defaults" "mode=755" ];
  };

  fileSystems."/boot" = {
    fsType = "btrfs";
    device = mountDevice;
    options = [ "subvol=boot" ] ++ mountOptions;
  };

  fileSystems."/nix" = {
    fsType = "btrfs";
    device = mountDevice;
    options = [ "subvol=nix" ] ++ mountOptions;
  };

  fileSystems."/persist" = {
    fsType = "btrfs";
    device = mountDevice;
    options = [ "subvol=persist" ] ++ mountOptions;
    neededForBoot = true;
  };
}

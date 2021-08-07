{ config, lib, pkgs, ... }:
let mountOptions = [
  "device=PARTUUID=d59a13b5-3e04-4d42-be80-1f1377d1e43c"
  "device=PARTUUID=eca0e072-abf6-2e4f-8221-6b5514a04a6c"
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
    options = [ "subvol=boot" ] ++ mountOptions;
  };

  fileSystems."/nix" = {
    fsType = "btrfs";
    options = [ "subvol=nix" ] ++ mountOptions;
  };

  fileSystems."/persist" = {
    fsType = "btrfs";
    options = [ "subvol=persist" ] ++ mountOptions;
    neededForBoot = true;
  };
}

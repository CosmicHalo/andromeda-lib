{
  boot.loader.grub.devices = ["nodev"];
  fileSystems."/" = {
    device = "test";
    fsType = "ext4";
  };

  system.stateVersion = "23.11";
}

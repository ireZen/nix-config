# ZedPool: the existing 4.5 TB ZFS pool from Proxmox (a mirror of two
# Samsung 1 TB SSDs, plus raidz1 vdevs of 5x Toshiba PX04 800 GB and 3x
# Samsung PM863 480 GB). It is imported as-is; NixOS never formats it.
#
# Incus keeps its VMs in ZedPool/incus. The old Proxmox disks
# (ZedPool/vm-10x-disk-*) stay beside it until you delete them.
{...}: {
  boot.supportedFilesystems = ["zfs"];
  boot.zfs = {
    extraPools = ["ZedPool"];
    forceImportRoot = false;
  };

  # ZFS requires a unique host ID. This is the first 8 hex digits of the
  # Proxmox install's machine-id.
  networking.hostId = "8e2bb523";

  # Cap the ARC so it doesn't compete with ~68 GiB of VM memory (the host
  # has 96 GB). Proxmox caps it at about 10% of RAM.
  boot.kernelParams = ["zfs.zfs_arc_max=${toString (8 * 1024 * 1024 * 1024)}"];

  # Proxmox scrubbed monthly and trimmed monthly; keep doing that.
  services.zfs = {
    autoScrub = {
      enable = true;
      interval = "monthly";
    };
    trim = {
      enable = true;
      interval = "monthly";
    };
  };
}

# The Unraid array, re-assembled without Unraid:
#
#   /mnt/disk1 … /mnt/diskN   each Unraid data disk, mounted as-is (XFS by default)
#   /mnt/parity1 [/mnt/parity2] the old Unraid parity disk(s), REFORMATTED for SnapRAID
#   /mnt/user                  mergerfs pool of all data disks (same path as Unraid,
#                              so share paths and NFS exports don't change)
#   /mnt/cache                 the old Unraid cache pool, mounted on its own
#
# Unraid parity cannot be reused: it is raw blocks with no filesystem. SnapRAID
# rebuilds parity from the data the first time you run `snapraid sync`.
{
  lib,
  pkgs,
  ...
}: let
  # ---------------------------------------------------------------------
  # CHANGE ME. Get UUIDs with `lsblk -f` / `blkid` on the NixOS installer.
  # Use partition 1 of each Unraid data disk (e.g. /dev/sdb1), NOT /dev/mdX.
  # Map the Unraid slot numbers (disk1, disk2, …) from Unraid's Main tab
  # by serial number so the names stay the same.
  dataDisks = {
    disk1 = {
      uuid = "00000000-0000-0000-0000-000000000001";
      fsType = "xfs";
    };
    disk2 = {
      uuid = "00000000-0000-0000-0000-000000000002";
      fsType = "xfs";
    };
  };

  # One entry per parity disk (two if Unraid had dual parity). These get
  # reformatted as ext4 during the migration, so fill in the NEW UUIDs.
  parityDisks = {
    parity1 = "00000000-0000-0000-0000-0000000000a1";
  };

  # Unraid cache pool; set to null if you have none.
  # A multi-device btrfs pool mounts by its single filesystem UUID.
  cache = {
    uuid = "00000000-0000-0000-0000-0000000000c1";
    fsType = "btrfs";
  };

  # SAFETY SWITCH. Leave true for the first boot: data disks and the pool
  # mount read-only, so nothing can write to them while you verify the
  # data and build SnapRAID parity. Flip to false once `snapraid sync` has
  # finished and you're happy.
  dataReadOnly = true;
  # ---------------------------------------------------------------------

  roOpt = lib.optional dataReadOnly "ro";

  dataMounts =
    lib.mapAttrs' (name: d:
      lib.nameValuePair "/mnt/${name}" {
        device = "/dev/disk/by-uuid/${d.uuid}";
        inherit (d) fsType;
        # nofail: a dead disk must not stop the NAS from booting.
        options = ["nofail" "noatime" "x-systemd.device-timeout=30s"] ++ roOpt;
      })
    dataDisks;

  parityMounts =
    lib.mapAttrs' (name: uuid:
      lib.nameValuePair "/mnt/${name}" {
        device = "/dev/disk/by-uuid/${uuid}";
        fsType = "ext4";
        options = ["nofail" "noatime" "x-systemd.device-timeout=30s"];
      })
    parityDisks;

  dataPaths = map (n: "/mnt/${n}") (lib.attrNames dataDisks);
  parityPaths = map (n: "/mnt/${n}") (lib.attrNames parityDisks);
in {
  system.fsPackages = [pkgs.mergerfs];
  environment.systemPackages = with pkgs; [mergerfs mergerfs-tools snapraid xfsprogs btrfs-progs e2fsprogs];

  fileSystems =
    dataMounts
    // parityMounts
    // {
      "/mnt/user" = {
        device = lib.concatStringsSep ":" dataPaths;
        fsType = "fuse.mergerfs";
        depends = dataPaths;
        noCheck = true;
        options =
          [
            "nofail"
            "allow_other"
            "fsname=mergerfs"
            # New files go to the disk with the most free space; similar to
            # Unraid's "most-free". Use "epmfs" to keep a folder's files on
            # the disks that already hold that folder (helps *arr hardlinks).
            "category.create=mfs"
            "minfreespace=50G"
            "moveonenospc=true"
            "cache.files=partial"
            "dropcacheonclose=true"
            # Stable inode numbers, needed for exporting the pool over NFS.
            "inodecalc=path-hash"
          ]
          ++ roOpt;
      };
    }
    // lib.optionalAttrs (cache != null) {
      "/mnt/cache" = {
        device = "/dev/disk/by-uuid/${cache.uuid}";
        inherit (cache) fsType;
        options = ["nofail" "noatime"];
      };
    };

  # --- SnapRAID ----------------------------------------------------------
  # First sync is manual and takes many hours:  sudo snapraid sync
  # After that, the timers below keep parity up to date.
  services.snapraid = {
    enable = true;
    dataDisks = lib.mapAttrs (name: _: "/mnt/${name}/") dataDisks;
    parityFiles =
      lib.imap1 (i: p:
        if i == 1
        then "${p}/snapraid.parity"
        else "${p}/snapraid.${toString i}-parity")
      parityPaths;
    # Content files must live on several disks. While the data disks are
    # read-only they can only go on the boot disk and the parity disks.
    contentFiles =
      ["/var/lib/snapraid/snapraid.content"]
      ++ map (p: "${p}/snapraid.content") parityPaths
      ++ lib.optionals (!dataReadOnly) (map (p: "${p}/snapraid.content") dataPaths);
    exclude = [
      "*.unrecoverable"
      "/tmp/"
      "/lost+found/"
      "*.!sync"
      ".Trash-*/"
      ".DS_Store"
    ];
    # `snapraid touch` writes timestamps, which a read-only disk refuses.
    touchBeforeSync = !dataReadOnly;
    sync.interval = "03:00";
    scrub = {
      interval = "Sun *-*-* 05:00:00";
      plan = 8;
      olderThan = 10;
    };
  };

  systemd.tmpfiles.rules = ["d /var/lib/snapraid 0755 root root -"];

  # Spin data disks down after 30 minutes idle, like Unraid's default.
  # (241 = 30 min in hdparm units; remove if your drives misbehave.)
  services.udev.extraRules = ''
    ACTION=="add|change", KERNEL=="sd[a-z]*", ENV{DEVTYPE}=="disk", ATTR{queue/rotational}=="1", RUN+="${pkgs.hdparm}/bin/hdparm -S 241 /dev/%k"
  '';
}

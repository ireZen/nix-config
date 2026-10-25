# Incus hypervisor: the NixOS replacement for Proxmox.
#
# Declared here, and re-applied on every rebuild (via Incus preseed):
#   - a "default" storage pool (homelab.incusStorage: a directory, or a ZFS
#     dataset that Incus creates and manages)
#   - a "default" profile whose eth0 is bridged onto the LAN bridge (br0),
#     so VMs get LAN addresses like they did on Proxmox's vmbr0
#   - the Incus web UI on https://<host>:8443
#
# VMs are declared with homelab.incusVMs.<name>. Because these VMs are
# existing disk images moved over from Proxmox, they are created once with
#
#   sudo incus-vm-import <name> <disk image or block device>
#
# which builds the VM from its declaration and copies the image in. After
# that, change a VM with `incus config set` or the web UI, and update its
# declaration here to match. Rebuilding never touches existing VMs.
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.incusVMs;
  storage = config.homelab.incusStorage;
  incus = config.virtualisation.incus.package;
  q = lib.escapeShellArg;

  # Where Incus keeps a VM's root disk, per storage driver.
  rootDiskPath =
    if storage.driver == "zfs"
    then "/dev/zvol/${storage.source}/virtual-machines/$name.block"
    else "${storage.source}/virtual-machines/$name/root.img";

  vmConfig = vm:
    {
      "limits.cpu" = toString vm.cpus;
      "limits.memory" = vm.memory;
      "boot.autostart" = lib.boolToString vm.autostart;
      "boot.autostart.priority" = toString vm.autostartPriority;
      "boot.host_shutdown_timeout" = toString vm.shutdownTimeout;
      "security.secureboot" = "false";
      # Legacy BIOS (SeaBIOS) for guests installed without UEFI, which is
      # Proxmox's default.
      "security.csm" = lib.boolToString vm.legacyBios;
    }
    // vm.extraConfig;

  createCommands = name: vm: let
    configFlags = lib.concatStringsSep " " (lib.mapAttrsToList (k: v: "-c ${q "${k}=${v}"}") (vmConfig vm));
    nicFlag = lib.optionalString (vm.mac != null) "-d ${q "eth0,hwaddr=${vm.mac}"}";
    usbCommands = lib.concatStrings (lib.mapAttrsToList (dev: usb: ''
        incus config device add ${q name} ${q dev} usb vendorid=${q usb.vendorid} productid=${q usb.productid}
      '')
      vm.usb);
    pciCommands = lib.concatStrings (lib.mapAttrsToList (dev: address: ''
        incus config device add ${q name} ${q dev} pci address=${q address}
      '')
      vm.pci);
  in ''
    ${q name})
      incus init ${q name} --empty --vm ${configFlags} -d ${q "root,size=${vm.diskSize}"} ${nicFlag}
      ${usbCommands}
      ${pciCommands}
      ;;
  '';

  vmImport = pkgs.writeShellApplication {
    name = "incus-vm-import";
    runtimeInputs = [incus pkgs.qemu-utils pkgs.jq pkgs.coreutils pkgs.util-linux pkgs.systemd];
    text = ''
      usage() {
        echo "usage: incus-vm-import <vm> <disk image (qcow2/raw) or block device, e.g. /dev/zvol/...>" >&2
        echo "declared VMs: ${lib.concatStringsSep " " (lib.attrNames cfg)}" >&2
        exit 1
      }
      [ "$#" -eq 2 ] || usage
      name=$1
      image=$2
      [ -r "$image" ] || { echo "cannot read $image" >&2; exit 1; }

      if incus info "$name" >/dev/null 2>&1; then
        echo "VM '$name' already exists in Incus; refusing to overwrite it." >&2
        exit 1
      fi

      case "$name" in
      ${lib.concatStrings (lib.mapAttrsToList createCommands cfg)}
      *) usage ;;
      esac

      # A block device (such as an old Proxmox zvol) is always raw; let
      # qemu-img detect the format of image files.
      fmt=()
      if [ -b "$image" ]; then fmt=(-f raw); fi

      root="${rootDiskPath}"
      udevadm settle
      for _ in $(seq 30); do [ -e "$root" ] && break; sleep 1; done
      [ -e "$root" ] || { echo "VM disk $root did not appear" >&2; incus delete "$name"; exit 1; }

      need=$(qemu-img info "''${fmt[@]}" --output=json "$image" | jq '."virtual-size"')
      if [ -b "$root" ]; then
        have=$(blockdev --getsize64 "$root")
      else
        have=$(stat -c %s "$root")
      fi
      if [ "$need" -gt "$have" ]; then
        echo "The image is $need bytes but the VM disk is only $have bytes." >&2
        echo "Raise diskSize for '$name', rebuild, and run this again." >&2
        incus delete "$name"
        exit 1
      fi

      echo "Copying $image into $name's disk..."
      # The new disk is empty, so skip writing zeros and keep it sparse.
      qemu-img convert -p "''${fmt[@]}" -n --target-is-zero -O raw "$image" "$root"
      echo "Done. Start it with:  incus start $name   (console: incus console $name --type=vga)"
    '';
  };
in {
  options.homelab.incusStorage = {
    driver = lib.mkOption {
      type = lib.types.enum ["dir" "zfs"];
      default = "dir";
      description = "Incus storage driver for the default pool.";
    };
    source = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/incus/storage-pools/default";
      example = "tank/incus";
      description = ''
        Directory (dir) or ZFS dataset (zfs) for the default pool. A ZFS
        dataset that doesn't exist yet is created by Incus; one that exists
        must be empty.
      '';
    };
  };

  options.homelab.incusVMs = lib.mkOption {
    default = {};
    description = "Incus VMs imported from existing disk images.";
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        cpus = lib.mkOption {
          type = lib.types.ints.positive;
          default = 2;
        };
        memory = lib.mkOption {
          type = lib.types.str;
          default = "4GiB";
        };
        diskSize = lib.mkOption {
          type = lib.types.str;
          default = "32GiB";
          description = "Size of the VM's disk. Must be at least the image's virtual size.";
        };
        mac = lib.mkOption {
          type = lib.types.nullOr lib.types.str;
          default = null;
          example = "bc:24:11:aa:bb:cc";
          description = "MAC address for eth0. Reuse the Proxmox MAC to keep DHCP reservations.";
        };
        legacyBios = lib.mkOption {
          type = lib.types.bool;
          default = false;
          description = "Boot with legacy BIOS (SeaBIOS) instead of UEFI.";
        };
        autostart = lib.mkOption {
          type = lib.types.bool;
          default = true;
        };
        autostartPriority = lib.mkOption {
          type = lib.types.int;
          default = 0;
          description = "VMs with higher values start first.";
        };
        shutdownTimeout = lib.mkOption {
          type = lib.types.ints.positive;
          default = 120;
          description = "Seconds to wait for a clean guest shutdown when the host stops.";
        };
        usb = lib.mkOption {
          default = {};
          description = "USB devices to pass through, by vendor and product ID (see `lsusb`).";
          example = {
            zigbee = {
              vendorid = "10c4";
              productid = "ea60";
            };
          };
          type = lib.types.attrsOf (lib.types.submodule {
            options = {
              vendorid = lib.mkOption {type = lib.types.str;};
              productid = lib.mkOption {type = lib.types.str;};
            };
          });
        };
        pci = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          example = {gpu = "0000:af:00.0";};
          description = ''
            PCI devices to pass through (device name -> PCI address). The host
            must have the IOMMU enabled; pass every function of a card.
          '';
        };
        extraConfig = lib.mkOption {
          type = lib.types.attrsOf lib.types.str;
          default = {};
          description = "Extra Incus instance config keys.";
        };
      };
    });
  };

  config = {
    # Incus on NixOS requires the nftables firewall backend.
    networking.nftables.enable = true;

    virtualisation.incus = {
      enable = true;
      ui.enable = true;
      preseed = {
        config."core.https_address" = ":8443";
        storage_pools = [
          {
            name = "default";
            inherit (storage) driver;
            config.source = storage.source;
          }
        ];
        profiles = [
          {
            name = "default";
            devices = {
              root = {
                type = "disk";
                path = "/";
                pool = "default";
              };
              eth0 = {
                type = "nic";
                name = "eth0";
                nictype = "bridged";
                parent = "br0";
              };
            };
          }
        ];
      };
    };

    # A ZFS pool must be imported before Incus starts.
    systemd.services.incus = lib.mkIf (storage.driver == "zfs") {
      wants = ["zfs-import.target"];
      after = ["zfs-import.target"];
    };

    networking.firewall.allowedTCPPorts = [8443]; # web UI / API

    users.users.${config.var.username}.extraGroups = ["incus-admin"];

    environment.systemPackages = [vmImport pkgs.qemu-utils];
  };
}

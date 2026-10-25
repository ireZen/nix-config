# Incus hypervisor: the NixOS replacement for Proxmox.
#
# Declared here, and re-applied on every rebuild (via Incus preseed):
#   - a "default" storage pool (dir driver, /var/lib/incus/storage-pools/default)
#   - a "default" profile whose eth0 is bridged onto the LAN bridge (br0),
#     so VMs get LAN addresses like they did on Proxmox's vmbr0
#   - the Incus web UI on https://<host>:8443
#
# VMs are declared with homelab.incusVMs.<name>. Because these VMs are
# existing disk images moved over from Proxmox, they are created once with
#
#   sudo incus-vm-import <name> /path/to/<name>.qcow2
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
  incus = config.virtualisation.incus.package;
  poolPath = "/var/lib/incus/storage-pools/default";
  q = lib.escapeShellArg;

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
  in ''
    ${q name})
      incus init ${q name} --empty --vm ${configFlags} -d ${q "root,size=${vm.diskSize}"} ${nicFlag}
      ${usbCommands}
      ;;
  '';

  vmImport = pkgs.writeShellApplication {
    name = "incus-vm-import";
    runtimeInputs = [incus pkgs.qemu-utils pkgs.jq pkgs.coreutils];
    text = ''
      usage() {
        echo "usage: incus-vm-import <vm> <disk-image (qcow2 or raw)>" >&2
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

      root="${poolPath}/virtual-machines/$name/root.img"
      need=$(qemu-img info --output=json "$image" | jq '."virtual-size"')
      have=$(stat -c %s "$root")
      if [ "$need" -gt "$have" ]; then
        echo "The image is $need bytes but the VM disk is only $have bytes." >&2
        echo "Raise diskSize for '$name', rebuild, and run this again." >&2
        incus delete "$name"
        exit 1
      fi

      echo "Copying $image into $name's disk..."
      qemu-img convert -p -n -O raw "$image" "$root"
      echo "Done. Start it with:  incus start $name   (console: incus console $name --type=vga)"
    '';
  };
in {
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
            driver = "dir";
            config.source = poolPath;
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

    networking.firewall.allowedTCPPorts = [8443]; # web UI / API

    users.users.${config.var.username}.extraGroups = ["incus-admin"];

    environment.systemPackages = [vmImport pkgs.qemu-utils];
  };
}

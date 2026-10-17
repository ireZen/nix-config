# KVM/libvirt hypervisor: the NixOS replacement for Proxmox.
#
# VMs are plain libvirt domain XML files kept in git. Declare them with
#
#   homelab.libvirtGuests.<name> = { xml = ./vms/<name>.xml; autostart = true; };
#
# <name> must match the <name> element inside the XML. On every boot and
# every `nixos-rebuild switch` that changes an XML file, the file is
# (re)defined with `virsh define`. Changes to a running VM take effect the
# next time it is fully shut down and started (not on a guest reboot).
#
# Manage the VMs from a desktop with virt-manager over SSH:
#   virt-manager -c qemu+ssh://<user>@callisto/system
{
  config,
  lib,
  pkgs,
  ...
}: let
  cfg = config.homelab.libvirtGuests;
  virsh = "${config.virtualisation.libvirtd.package}/bin/virsh";
in {
  options.homelab.libvirtGuests = lib.mkOption {
    default = {};
    description = "libvirt domains defined from XML files in this repo.";
    type = lib.types.attrsOf (lib.types.submodule {
      options = {
        xml = lib.mkOption {
          type = lib.types.path;
          description = "Path to the libvirt domain XML.";
        };
        autostart = lib.mkOption {
          type = lib.types.bool;
          default = true;
          description = "Start the VM when the host boots.";
        };
      };
    });
  };

  config = {
    virtualisation.libvirtd = {
      enable = true;
      qemu = {
        package = pkgs.qemu_kvm;
        runAsRoot = false;
        swtpm.enable = true; # virtual TPM, in case a guest ever needs one
      };
      # Shut guests down cleanly (Home Assistant's database, game saves)
      # instead of libvirt's default of suspending them to disk.
      onBoot = "ignore"; # per-VM autostart flags decide what starts
      onShutdown = "shutdown";
      shutdownTimeout = 300;
    };

    users.users.${config.var.username}.extraGroups = ["libvirtd"];

    environment.systemPackages = with pkgs; [
      libguestfs # virt-* image tools
      config.virtualisation.libvirtd.qemu.package # provides qemu-img
    ];

    systemd.services.libvirt-define-guests = lib.mkIf (cfg != {}) {
      description = "Define libvirt guests from the NixOS configuration";
      after = ["libvirtd.service"];
      requires = ["libvirtd.service"];
      wantedBy = ["multi-user.target"];
      restartTriggers = lib.mapAttrsToList (_: g: g.xml) cfg;
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
      };
      script = lib.concatStringsSep "\n" (lib.mapAttrsToList (name: g: ''
          echo "Defining ${name}"
          ${virsh} define ${g.xml}
          ${
            if g.autostart
            then ''
              ${virsh} autostart ${name}
              if [ "$(${virsh} domstate ${name})" != "running" ]; then
                ${virsh} start ${name} || echo "warning: could not start ${name}" >&2
              fi
            ''
            else "${virsh} autostart --disable ${name}"
          }
        '')
        cfg);
    };
  };
}

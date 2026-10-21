# callisto: KVM hypervisor replacing Proxmox.
# Runs the existing Home Assistant OS, Docker and CubeCoders AMP VMs, moved
# over as disk images (see docs/homelab-migration.md).
{...}: {
  imports = [
    ../modules/server/base.nix
    ../modules/server/libvirt-host.nix

    ./hardware-configuration.nix
    ./variables.nix
    ./network.nix
  ];

  homelab.libvirtGuests = {
    haos = {
      xml = ./vms/haos.xml;
      autostart = true;
    };
    docker = {
      xml = ./vms/docker.xml;
      autostart = true;
    };
    amp = {
      xml = ./vms/amp.xml;
      autostart = true;
    };
  };

  # Set this to whatever `nixos-generate-config` writes on the day you install,
  # then never change it.
  system.stateVersion = "26.11";
}

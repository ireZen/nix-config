# Bridged networking, the equivalent of Proxmox's vmbr0: VMs sit directly on
# the LAN and keep their own IPs/DHCP reservations.
let
  # CHANGE ME: physical NIC name (`ip link` on the installer) and the
  # address the Proxmox host uses today (vmbr0 in /etc/network/interfaces).
  uplink = "enp1s0";
  address = "192.168.1.10/24";
  gateway = "192.168.1.1";
  dns = ["192.168.1.1"];
in {
  systemd.network = {
    netdevs."10-br0".netdevConfig = {
      Name = "br0";
      Kind = "bridge";
    };

    networks."10-uplink" = {
      matchConfig.Name = uplink;
      networkConfig.Bridge = "br0";
      linkConfig.RequiredForOnline = "enslaved";
    };

    networks."20-br0" = {
      matchConfig.Name = "br0";
      address = [address];
      routes = [{Gateway = gateway;}];
      inherit dns;
      networkConfig.ConfigureWithoutCarrier = true;
      linkConfig.RequiredForOnline = "routable";
    };
  };
}

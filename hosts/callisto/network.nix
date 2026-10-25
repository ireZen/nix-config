# Bridged networking, the equivalent of Proxmox's vmbr0: VMs sit directly on
# the LAN and keep their own IPs/DHCP reservations.
#
# Proxmox called the uplink "nic0" (port 1 of the Intel X710). NixOS names it
# differently, so match it by MAC address instead of by name. The bridge
# takes the same MAC, like vmbr0 did, so the router sees no change.
let
  uplinkMac = "f8:f2:1e:66:53:60";
  address = "10.0.0.16/22";
  gateway = "10.0.0.1";
  dns = ["10.0.0.1"];
  domain = "grey.lan";
in {
  systemd.network = {
    netdevs."10-br0".netdevConfig = {
      Name = "br0";
      Kind = "bridge";
      MACAddress = uplinkMac;
    };

    networks."10-uplink" = {
      matchConfig.PermanentMACAddress = uplinkMac;
      networkConfig.Bridge = "br0";
      linkConfig.RequiredForOnline = "enslaved";
    };

    networks."20-br0" = {
      matchConfig.Name = "br0";
      address = [address];
      routes = [{Gateway = gateway;}];
      inherit dns;
      domains = [domain];
      networkConfig.ConfigureWithoutCarrier = true;
      linkConfig.RequiredForOnline = "routable";
    };
  };
}

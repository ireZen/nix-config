# Static address for the NAS. Keep the SAME IP Unraid has today so every
# client (Docker VM mounts, Home Assistant backups, desktops) keeps working.
let
  # CHANGE ME: NIC name (`ip link` on the installer) and Unraid's current address.
  nic = "enp1s0";
  address = "192.168.1.20/24";
  gateway = "192.168.1.1";
  dns = ["192.168.1.1"];
in {
  systemd.network.networks."10-lan" = {
    matchConfig.Name = nic;
    address = [address];
    routes = [{Gateway = gateway;}];
    inherit dns;
    linkConfig.RequiredForOnline = "routable";
  };
}

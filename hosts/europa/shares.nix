# SMB and NFS shares, laid out like Unraid's so existing clients keep working:
# same share names, same paths (/mnt/user/<share>), same file owner.
{
  config,
  lib,
  pkgs,
  ...
}: let
  # CHANGE ME: your Unraid share names (Unraid → Shares tab), and which of
  # them are exported over NFS.
  smbShares = ["media" "backups" "isos"];
  nfsShares = ["media" "backups"];

  # CHANGE ME: networks allowed to use the shares (LAN, plus VPN ranges if any).
  allowedNets = ["192.168.1.0/24"];
in {
  # Unraid writes share files as nobody:users = 99:100. NixOS's own "nobody"
  # is 65534, so add a user with uid 99 to keep ownership and permissions
  # identical on the existing data. Containers that used PUID=99 PGID=100
  # keep working against these shares.
  users.users.share = {
    uid = 99;
    group = "users";
    isSystemUser = true;
    description = "Owner of share files (Unraid's nobody)";
  };

  # --- SMB ---------------------------------------------------------------
  # Samba keeps its own password db, separate from the unix password, and it
  # can't be set declaratively. Instead of running `smbpasswd -a` by hand,
  # the smb-setpw service below loads it from a sops secret on every boot.
  # Put the password in secrets/europa.yaml under the key `smb-angerzen`:
  #   sops secrets/europa.yaml
  sops.secrets.smb-angerzen.sopsFile = ../../secrets/europa.yaml;

  systemd.services.smb-setpw = {
    description = "Set the Samba password from the sops secret";
    after = ["samba-smbd.service"];
    wantedBy = ["multi-user.target"];
    serviceConfig.Type = "oneshot";
    script = ''
      pw=$(cat ${config.sops.secrets.smb-angerzen.path})
      printf '%s\n%s\n' "$pw" "$pw" \
        | ${pkgs.samba}/bin/smbpasswd -s -a ${config.var.username}
    '';
  };

  services.samba = {
    enable = true;
    openFirewall = true;
    settings =
      {
        global = {
          "workgroup" = "WORKGROUP";
          "server string" = config.var.hostname;
          "netbios name" = config.var.hostname;
          "security" = "user";
          "map to guest" = "never";
          "server min protocol" = "SMB2_10";
          "hosts allow" = lib.concatStringsSep " " (allowedNets ++ ["127.0.0.1"]);
          "hosts deny" = "0.0.0.0/0";
          # macOS niceties (Unraid's "Enhanced macOS interoperability")
          "vfs objects" = "catia fruit streams_xattr";
          "fruit:metadata" = "stream";
          "fruit:model" = "MacSamba";
        };
      }
      // lib.genAttrs smbShares (name: {
        "path" = "/mnt/user/${name}";
        "browseable" = "yes";
        "read only" = "no";
        "guest ok" = "no";
        "valid users" = "@users";
        "force user" = "share";
        "force group" = "users";
        "create mask" = "0664";
        "directory mask" = "0775";
      });
  };

  # Lets Windows 10/11 see the NAS under Network.
  services.samba-wsdd = {
    enable = true;
    openFirewall = true;
  };

  # --- NFS ---------------------------------------------------------------
  # Same export options Unraid uses for public NFS shares: everyone is
  # squashed to 99:100. fsid is required because /mnt/user is a FUSE mount.
  services.nfs.server = {
    enable = true;
    # Fixed ports so NFSv3 clients get through the firewall.
    statdPort = 4000;
    lockdPort = 4001;
    mountdPort = 4002;
    exports = lib.concatStrings (lib.imap1 (i: name: let
        opts = "rw,sync,insecure,no_subtree_check,all_squash,anonuid=99,anongid=100,fsid=${toString (100 + i)}";
      in "/mnt/user/${name} ${lib.concatMapStringsSep " " (net: "${net}(${opts})") allowedNets}\n")
      nfsShares);
  };

  networking.firewall = {
    allowedTCPPorts = [111 2049 4000 4001 4002];
    allowedUDPPorts = [111 2049 4000 4001 4002];
  };
}

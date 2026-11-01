{ config, ... }: {
  # User login password, decrypted from secrets/common.yaml by sops-nix.
  # `neededForUsers` decrypts it early (to /run/secrets-for-users) so it is
  # available when the account is created. Put a sha-512 hash in the secret:
  #   mkpasswd -m sha-512 | sops secrets/common.yaml   (key: user-password)
  sops.secrets.user-password = {
    sopsFile = ../../secrets/common.yaml;
    neededForUsers = true;
  };

  users = {
    mutableUsers = false;
    users.${config.var.username} = {
      isNormalUser = true;
      description = "${config.var.username} account";
      extraGroups = [ "networkmanager" "wheel" "kvm" "video" "input"];
      hashedPasswordFile = config.sops.secrets.user-password.path;
    };
  };
}

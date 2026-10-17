{config, ...}: {
  imports = [../modules/variables-config.nix];

  config.var = {
    hostname = "callisto";
    username = "angerzen";
    homeDirectory = "/home/" + config.var.username;
    configDirectory = config.var.homeDirectory + "/nix-config";

    keyboardLayout = "us";

    timeZone = "America/Chicago";
    defaultLocale = "en_US.UTF-8";
    extraLocale = "en_US.UTF-8";

    git = {
      username = "ireZen";
      email = "297648004+ireZen@users.noreply.github.com";
    };

    # CHANGE ME: paste your desktop/laptop public keys (cat ~/.ssh/id_ed25519.pub).
    # Password SSH login stays enabled until this list is non-empty.
    sshAuthorizedKeys = [
      # "ssh-ed25519 AAAA... angerzen@ganymede"
    ];
  };
}

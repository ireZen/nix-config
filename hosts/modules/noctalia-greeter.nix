{config, ...}: {
  services.displayManager.noctalia-greeter = {
    enable = true;
    passwordless-sync-users = [config.var.username];
  };
}

{...}: {
  services.openssh = {
    enable = true;
    openFirewall = false;   # laptop/desktop: key exists & is managed, but port 22 stays closed
    settings = {
      PasswordAuthentication = false;
      KbdInteractiveAuthentication = false;
    };
  };
}
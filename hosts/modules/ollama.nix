{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true; # needed for CUDA packages

  services.ollama = {
    enable = true;
    acceleration = "cuda";
    # Listens on localhost:11434 by default. Uncomment to reach it from
    # other devices on your LAN:
    # host = "0.0.0.0";
  };

  # Optional web UI instead of the CLI, served at http://localhost:8080
  services.open-webui = {
    enable = true;
    port = 8080;
  };
}
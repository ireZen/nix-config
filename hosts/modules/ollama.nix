{pkgs, ...}: {
  nixpkgs.config.allowUnfree = true; # needed for CUDA packages

  services.ollama = {
    enable = true;
    package = pkgs.ollama-cuda;
    # host = "0.0.0.0"; # uncomment to reach it from other devices on your LAN
  };

  # Optional web UI instead of the CLI, served at http://localhost:8080
  services.open-webui = {
    enable = true;
    port = 8080;
  };
}
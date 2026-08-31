{
  pkgs,
  config,
  ...
}: {
  services.xserver.videoDrivers = ["nvidia"]; # or "nvidiaLegacy470 etc.

  environment.variables = {
    LIBVA_DRIVER_NAME = "nvidia";
    XDG_SESSION_TYPE = "wayland";
    GBM_BACKEND = "nvidia-drm";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    NIXOS_OZONE_WL = "1";
  };

  environment.systemPackages = with pkgs; [
    nvidia-vaapi-driver
    libva-utils
  ];

  hardware = {
    graphics = {
      enable = true;
      enable32Bit = true;
    };
    nvidia = {
      # Turing (RTX 20xx) and newer: NVIDIA recommends the open kernel
      # modules over the proprietary ones. Only set this to false if the
      # card predates Turing.
      open = true;
      nvidiaSettings = true;
      powerManagement.enable = false; # This can cause sleep/suspend to fail and saves entire VRAM to /tmp/
      modesetting.enable = true;
      package = config.boot.kernelPackages.nvidiaPackages.latest;
    };
  };
}

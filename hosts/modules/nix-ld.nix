{pkgs, ...}: {
  programs.nix-ld = {
    enable = true;
    # Extra libraries available to generic binaries. The defaults cover the
    # common cases; add here if a specific binary complains about a missing .so
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      openssl
      libglvnd
      libGL
      gtk3
      glib
      nss
      nspr
      alsa-lib
      libpulseaudio
      libX11
      libXcursor
      libXrandr
      libXi
      libXext
      libXrender
      libXxf86vm
      zlib
      openssl
      icu
      libuuid
      stdenv.cc.cc.lib
      vulkan-loader
      gdk-pixbuf
      pango
      cairo
      harfbuzz
      atk
      fontconfig
      dbus
      wayland
      ncurses
      ocl-icd
    ];
  };
}
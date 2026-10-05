{pkgs, ...}: {
  programs.nix-ld = {
    enable = true;
    # Extra libraries available to generic binaries. The defaults cover the
    # common cases; add here if a specific binary complains about a missing .so
    libraries = with pkgs; [
      stdenv.cc.cc.lib
      zlib
      openssl
    ];
  };
}
{pkgs, ...}: {
  home.packages = with pkgs; [
    lutris
    winetricks
    protonup-qt
    protontricks
    wine
    gamescope
  ];
}

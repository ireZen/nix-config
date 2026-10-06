{pkgs, ...}: {
  home.packages = with pkgs; [
    unityhub          # Hub + Editor FHS wrapper (unfree — your allowUnfreePredicate already covers it)
  ];
}
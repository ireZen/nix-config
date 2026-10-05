{pkgs, ...}: {
  home.packages = with pkgs; [
    unityhub          # Hub + Editor FHS wrapper (unfree — your allowUnfreePredicate already covers it)
    dotnet-sdk_9      # needed by the C# language server in VSCodium
    git               # Unity Package Manager uses it for git-based packages
  ];
}
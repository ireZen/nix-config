{ config, ... }: {
  programs.git = {
    enable = true;
    settings = {
      user.name = "ireZen";
      user.email = "297648004+ireZen@users.noreply.github.com";
      ignores = [
        ".cache/"
        ".DS_Store"
        ".idea/"
        "*.swp"
        "*.elc"
        "auto-save-list"
        ".direnv/"
        "node_modules"
        "result"
        "result-*"
      ];
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };
}

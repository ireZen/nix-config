{ config, ... }: {
  programs.git = {
    enable = true;
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
    settings = {
      user.name = "ireZen";
      user.email = "297648004+ireZen@users.noreply.github.com";
      init.defaultBranch = "main";
      push.autoSetupRemote = true;
    };
  };
}

{...}: {
  # Enables greetd + accounts-daemon and sets default_session to
  # noctalia-greeter-session; see the noctalia-greeter nixosModules.default
  # import wired in flake.nix.
  programs.noctalia-greeter.enable = true;
}

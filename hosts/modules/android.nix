{...}: {
  programs.adb.enable = true;   # installs android-udev-rules, creates the adbusers group
  virtualisation.libvirtd.enable = false;  # not needed; just the kvm group
  users.users.angerzen.extraGroups = ["kvm"];
}
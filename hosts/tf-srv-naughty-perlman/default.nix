{ ... }: {
  imports = [ ./hardware-configuration.nix ];

  boot.cleanTmpDir = true;
  zramSwap.enable = true;
  networking.hostName = "tf-srv-naughty-perlman";
  services.openssh.enable = true;
  services.tailscale.enable = true;
  networking.firewall.checkReversePath = "loose";
  users.users.root.openssh.authorizedKeys.keys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM6NPbPIcCTzeEsjyx0goWyj6fr2qzcfKCCdOUqg0N/" # alrest
  ];
  system.stateVersion = "23.05";
}

{ ... }: {
  system.autoUpgrade = {
    enable = true;
    flake = "github:Xe/automagic-terraform-nixos";
  };
}

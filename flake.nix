{
  description = "A very basic flake";

  inputs = {
    nixpkgs.url = "nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      mkSystem = extraModules:
        nixpkgs.lib.nixosSystem rec {
          system = "x86_64-linux";
          modules = [ ] ++ extraModules;
        };
    in flake-utils.lib.eachSystem [ "x86_64-linux" "aarch64-linux" ] (system:
      let pkgs = import nixpkgs { inherit system; };
      in rec {
        devShell =
          pkgs.mkShell { buildInputs = with pkgs; [ terraform awscli2 ]; };
      }) // {
        nixosConfigurations = let hosts = builtins.readDir ./hosts;
        in builtins.mapAttrs (name: _: mkSystem [ ./hosts/${name} ]) hosts;
      };
}

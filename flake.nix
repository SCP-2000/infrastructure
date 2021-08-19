{
  description = "Foundational infrastructure of SCP-2000";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable-small";
    flake-utils.url = "github:numtide/flake-utils";
    impermanence.url = "github:nix-community/impermanence";
    nixbot = {
      url = "github:Ninlives/nixbot-telegram";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.flake-utils.follows = "flake-utils";
    };
    deploy-rs = {
      url = "github:serokell/deploy-rs";
      inputs.nixpkgs.follows = "nixpkgs";
      inputs.utils.follows = "flake-utils";
    };
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, flake-utils, ... }: {
    nixosConfigurations = {
      hel0 = import ./nixos/hel0 { system = "x86_64-linux"; inherit self nixpkgs inputs; };
    };
    deploy.nodes = {
      hel0 = {
        sshUser = "root";
        hostname = "hel0.nichi.link";
        profiles.system.path = inputs.deploy-rs.lib.x86_64-linux.activate.nixos self.nixosConfigurations.hel0;
      };
    };
  };
}

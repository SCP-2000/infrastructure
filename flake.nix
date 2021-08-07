{
  description = "Foundational infrastructure of SCP-2000";
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
    impermanence.url = "github:nix-community/impermanence";
    sops-nix = {
      url = "github:Mic92/sops-nix";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs@{ self, nixpkgs, flake-utils, ... }: {
    nixosConfigurations = {
      hel0 = import ./nixos/hel0 { system = "x86_64-linux"; inherit self nixpkgs inputs; };
    };
  };
}

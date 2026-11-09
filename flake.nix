{
  description = "devenv flake";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
    devenv = {
      url = "github:cachix/devenv";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    nixpkgs-python.url = "github:cachix/nixpkgs-python";
  };

  outputs = { self, nixpkgs, devenv, ... }@inputs: let
    system = "x86_64-linux";
    # pkgs = nixpkgs.legacyPackages.${system};
    pkgs = import nixpkgs {
      inherit system;
      config.allowUnfreePredicate = pkg:
        builtins.elem (nixpkgs.lib.getName pkg) [ "vault-bin" ];
    };
  in
  {
    # use command to enter shell
    # nix develop --no-pure-eval
    devShells.${system}.default = devenv.lib.mkShell {
      inherit inputs pkgs;
      modules = [ ./devenv.nix ];
    };
  };
}

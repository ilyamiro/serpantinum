{
  description = "Serpantinum - a desktop shell built for YOU.";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

    ski = {
      url = "github:ilyamiro/Ski";
      flake = false;
    };

    serpantinum-wallpapers = {
      url = "github:ilyamiro/shell-wallpapers";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, ski, serpantinum-wallpapers, ... }:
    let
      supportedSystems = [ "x86_64-linux" "aarch64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;
      pkgsFor = system: import nixpkgs { inherit system; };
    in
    {
      overlays.default = final: _prev: {
        serpantinum = final.callPackage ./nix/package.nix {
          rev = self.rev or self.dirtyRev or "dirty";
        };
      };

      packages = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.callPackage ./nix/package.nix {
            rev = self.rev or self.dirtyRev or "dirty";
          };
          serpantinum = self.packages.${system}.default;
          ski = import ski { pkgs = pkgsFor system; };
        });

      apps = forAllSystems (system: {
        default = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/serpantinum";
        };
        serpantinumd = {
          type = "app";
          program = "${self.packages.${system}.default}/bin/serpantinumd";
        };
      });

      devShells = forAllSystems (system:
        let pkgs = pkgsFor system;
        in {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.default ];
            packages = with pkgs; [ nixpkgs-fmt nil ];
          };
        });

      homeManagerModules.default = import ./nix/hm-module.nix {
        inherit self;
        wallpapers = serpantinum-wallpapers;
      };
      homeManagerModules.serpantinum = self.homeManagerModules.default;

      nixosModules.default = {
        imports = [ ./nix/nixos-module.nix "${ski}/nix/module.nix" ];
      };
      nixosModules.serpantinum = self.nixosModules.default;

      formatter = forAllSystems (system: (pkgsFor system).nixpkgs-fmt);
    };
}

{
  description = "Declarative Nix packaging for the Rime Wanxiang schema";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
  };

  outputs = { self, nixpkgs }:
    let
      lib = nixpkgs.lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      overlay = final: prev: {
        rimeWanxiang = final.callPackage ./pkgs/wanxiang.nix {
          metadata = import ./nix/metadata.nix;
        };
      };
    in
    {
      overlays.default = overlay;

      lib = {
        metadata = import ./nix/metadata.nix;
      };

      packages = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          wanxiang-base = pkgs.rimeWanxiang.mkWanxiangPackage {
            schema = "base";
            fuzhu = "base";
            withDict = true;
            withGram = true;
          };

          wanxiang-flypy = pkgs.rimeWanxiang.mkWanxiangPackage {
            schema = "pro";
            fuzhu = "flypy";
            withDict = true;
            withGram = true;
          };

          wanxiang-zrm = pkgs.rimeWanxiang.mkWanxiangPackage {
            schema = "pro";
            fuzhu = "zrm";
            withDict = true;
            withGram = true;
          };

          default = self.packages.${system}.wanxiang-flypy;
        });

      checks = forAllSystems (system:
        let
          pkgs = import nixpkgs {
            inherit system;
            overlays = [ overlay ];
          };
        in
        {
          build-base = self.packages.${system}.wanxiang-base;
          build-default = self.packages.${system}.default;
          metadata-script = pkgs.runCommand "update-metadata-syntax" {
            nativeBuildInputs = [ pkgs.bash ];
          } ''
            bash -n ${./scripts/update-metadata.sh}
            touch "$out"
          '';
        });

      devShells = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        {
          default = pkgs.mkShell {
            packages = with pkgs; [
              curl
              jq
              nix
              nixpkgs-fmt
              rsync
              shellcheck
              unzip
            ];
          };
        });

      formatter = forAllSystems (system:
        let
          pkgs = import nixpkgs { inherit system; };
        in
        pkgs.nixpkgs-fmt);

      homeManagerModules.default = import ./modules/home-manager.nix;
    };
}

{
  description = "Nix flake for CLIProxyAPI - AI CLI proxy service";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { self, nixpkgs, flake-utils }:
    let
      # Supported systems for CLIProxyAPI
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # Version and hash information (updated by GitHub Action)
      version = "6.7.16";
      hashes = {
        "x86_64-linux" = "sha256-taKvgU4nCFTzW7RLK3XRvbpQyGfwvucy+C14JUBqP84=";
        "aarch64-linux" = "sha256-L/0bmPM55xiP7MI/s+iCXvJHw5reC2DKaA7OxqOVdO0=";
        "x86_64-darwin" = "sha256-pE4jsHO71mrVrEPzYyVU0mwrq+GAZcUnpK6rr2a6VVE=";
        "aarch64-darwin" = "sha256-YQ5Bb42xpTs4Eic6wpURC505Q4ChKT/yzw5Ix8kCoSQ=";
      };

      # Map Nix system to release asset naming
      systemToAsset = system: {
        "x86_64-linux" = "linux_amd64";
        "aarch64-linux" = "linux_arm64";
        "x86_64-darwin" = "darwin_amd64";
        "aarch64-darwin" = "darwin_arm64";
      }.${system};

      # Package builder for each system
      mkPackage = pkgs: system:
        let
          asset = systemToAsset system;
        in
        pkgs.stdenv.mkDerivation {
          pname = "cliproxyapi";
          inherit version;

          src = pkgs.fetchurl {
            url = "https://github.com/router-for-me/CLIProxyAPI/releases/download/v${version}/CLIProxyAPI_${version}_${asset}.tar.gz";
            hash = hashes.${system};
          };

          sourceRoot = ".";

          nativeBuildInputs = [ pkgs.autoPatchelfHook ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib ];

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            cp cli-proxy-api $out/bin/cliproxyapi

            # Install the example config for reference
            mkdir -p $out/share/cliproxyapi
            if [ -f config.example.yaml ]; then
              cp config.example.yaml $out/share/cliproxyapi/
            fi

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = "AI CLI proxy service providing OpenAI/Gemini/Claude compatible API";
            homepage = "https://github.com/router-for-me/CLIProxyAPI";
            license = licenses.mit;
            platforms = supportedSystems;
            mainProgram = "cliproxyapi";
          };
        };

    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs { inherit system; };
      in
      {
        packages = {
          cliproxyapi = mkPackage pkgs system;
          default = self.packages.${system}.cliproxyapi;
        };

        apps = {
          cliproxyapi = flake-utils.lib.mkApp {
            drv = self.packages.${system}.cliproxyapi;
          };
          default = self.apps.${system}.cliproxyapi;
        };
      }
    ) // {
      # NixOS module
      nixosModules = {
        cliproxyapi = import ./modules/nixos.nix self;
        default = self.nixosModules.cliproxyapi;
      };

      # nix-darwin module
      darwinModules = {
        cliproxyapi = import ./modules/darwin.nix self;
        default = self.darwinModules.cliproxyapi;
      };

      # Overlay for use with nixpkgs
      overlays.default = final: prev: {
        cliproxyapi = self.packages.${prev.system}.cliproxyapi;
      };
    };
}

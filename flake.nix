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
      version = "6.7.47";
      hashes = {
        "x86_64-linux" = "sha256-mrelE/jc5bikDGTN3U3CWY8CC/aMdRu2MKPYCqho7ws=";
        "aarch64-linux" = "sha256-PLesjZPGreuPn0cKJBTpyZPnIhev8Z6cadjR6iTuNrQ=";
        "x86_64-darwin" = "sha256-EcX5duWI1wkQxYKz72CBx/0e68nq9Mzu3RC/fzXr+HA=";
        "aarch64-darwin" = "sha256-vxw8XzUUH5E6ITDbmCTmPluafhdauk1mi9E60cVJ4kM=";
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

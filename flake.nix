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

      # Map Nix system to release asset naming
      systemToAsset = system: {
        "x86_64-linux" = "linux_amd64";
        "aarch64-linux" = "linux_arm64";
        "x86_64-darwin" = "darwin_amd64";
        "aarch64-darwin" = "darwin_arm64";
      }.${system};

      # Edition metadata (updated by GitHub Action per edition)
      editions = {
        cliproxyapi = {
          version = "6.8.30";
          hashes = {
            "x86_64-linux" = "sha256-u+/z7uDrVi6Pocsge50WF7lsEGxdv4v7D5UVX6XPeq0=";
            "aarch64-linux" = "sha256-J4YTAfxvJyO5w308uTEXp8kmC29pVlnrx9JPbtiqHGg=";
            "x86_64-darwin" = "sha256-jnP9mCCNs5njAsa80hmy0tKfIraidnvzaPHrWaPJRrk=";
            "aarch64-darwin" = "sha256-UwkiUpUdj421vbjkpkrKiaF2FkvdPUR4TMBnF1gWE6s=";
          };
          repo = "router-for-me/CLIProxyAPI";
          archivePrefix = "CLIProxyAPI";
          binaryName = "cli-proxy-api";
          license = pkgs: pkgs.lib.licenses.mit;
          description = "AI CLI proxy service providing OpenAI/Gemini/Claude compatible API";
          homepage = "https://github.com/router-for-me/CLIProxyAPI";
        };
        cliproxyapi-plus = {
          version = "6.8.28-1";
          hashes = {
            "x86_64-linux" = "sha256-lTM6/FjHsi7vgJHsSYtz6ajhiHklC/qkWpi1bVsGOKE=";
            "aarch64-linux" = "sha256-aamCGQ8Zu7ooho/TswC3MPyWxYBGwWpqoG2NUI6Cgpg=";
            "x86_64-darwin" = "sha256-mEltGpbIN+lHLdTJ5slrDfBz1tE4WnNKNSKMLCw2EeI=";
            "aarch64-darwin" = "sha256-hIfr5bowG6P9tyTxfs2Ozp9seMK2xTfNNjrwEhJrJuw=";
          };
          repo = "router-for-me/CLIProxyAPIPlus";
          archivePrefix = "CLIProxyAPIPlus";
          binaryName = "cli-proxy-api-plus";
          license = pkgs: pkgs.lib.licenses.mit;
          description = "AI CLI proxy service (Plus edition) with enhanced features";
          homepage = "https://github.com/router-for-me/CLIProxyAPIPlus";
        };
        cliproxyapi-business = {
          version = "2026.7.1";
          hashes = {
            "x86_64-linux" = "sha256-rj4OKQfTOhhilopj6ma8XrtHc/8rS6m4Cq9y9i2IzmM=";
            "aarch64-linux" = "sha256-/07ItHaIwa63oEGcTFV78Vk0m1xuuCOFi+8HKIq5dJ8=";
            "x86_64-darwin" = "sha256-/NOGwZuqBHJ4o1wKAI+bffCAfN9/A9TvPTU63IHcyqk=";
            "aarch64-darwin" = "sha256-jkJySOdbJR6xhNXOkmezHF7CUGXgRNugT7NYtUMzi4E=";
          };
          repo = "router-for-me/CLIProxyAPIBusiness";
          archivePrefix = "cpab";
          binaryName = "cpab";
          license = pkgs: pkgs.lib.licenses.sspl;
          description = "AI CLI proxy service (Business edition) for enterprise use";
          homepage = "https://github.com/router-for-me/CLIProxyAPIBusiness";
        };
      };

      # Package builder for each system and edition
      mkPackage = pkgs: system: editionName: edition:
        let
          asset = systemToAsset system;
        in
        pkgs.stdenv.mkDerivation {
          pname = editionName;
          version = edition.version;

          src = pkgs.fetchurl {
            url = "https://github.com/${edition.repo}/releases/download/v${edition.version}/${edition.archivePrefix}_${edition.version}_${asset}.tar.gz";
            hash = edition.hashes.${system};
          };

          sourceRoot = ".";

          nativeBuildInputs = [ pkgs.autoPatchelfHook ] ++ pkgs.lib.optionals pkgs.stdenv.isLinux [ pkgs.stdenv.cc.cc.lib ];

          installPhase = ''
            runHook preInstall

            mkdir -p $out/bin
            cp ${edition.binaryName} $out/bin/cliproxyapi

            # Install the example config for reference
            mkdir -p $out/share/cliproxyapi
            if [ -f config.example.yaml ]; then
              cp config.example.yaml $out/share/cliproxyapi/
            fi

            runHook postInstall
          '';

          meta = with pkgs.lib; {
            description = edition.description;
            homepage = edition.homepage;
            license = edition.license pkgs;
            platforms = supportedSystems;
            mainProgram = "cliproxyapi";
          };
        };

    in
    flake-utils.lib.eachSystem supportedSystems (system:
      let
        pkgs = import nixpkgs { inherit system; config.allowUnfree = true; };
      in
      {
        packages = builtins.mapAttrs (name: edition: mkPackage pkgs system name edition) editions
          // { default = self.packages.${system}.cliproxyapi; };

        apps = builtins.mapAttrs (name: pkg: flake-utils.lib.mkApp { drv = pkg; name = "cliproxyapi"; }) self.packages.${system}
          // { default = self.apps.${system}.cliproxyapi; };
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
      overlays.default = final: prev:
        builtins.mapAttrs (name: edition:
          self.packages.${prev.system}.${name}
        ) editions;
    };
}

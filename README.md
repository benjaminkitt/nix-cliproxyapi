# nix-cliproxyapi

Nix flake for [CLIProxyAPI](https://github.com/router-for-me/CLIProxyAPI) - an AI CLI proxy service providing OpenAI/Gemini/Claude compatible API.

## Features

- Package for Linux (x86_64, aarch64) and macOS (Intel, Apple Silicon)
- NixOS module with systemd service
- nix-darwin module with launchd service
- Optional storage backends: Git, PostgreSQL, S3
- Automatic version updates via GitHub Actions

## Quick Start

### Try it out

```bash
nix run github:benjaminkitt/nix-cliproxyapi
```

### Add to your flake

```nix
{
  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    cliproxyapi.url = "github:benjaminkitt/nix-cliproxyapi";
  };

  outputs = { self, nixpkgs, cliproxyapi }: {
    # Your configuration here
  };
}
```

## NixOS Configuration

### Basic Setup

```nix
{ inputs, ... }:

{
  imports = [ inputs.cliproxyapi.nixosModules.default ];

  services.cliproxyapi = {
    enable = true;
    openFirewall = true;  # Optional: open port 8317
  };
}
```

This will:
- Create a `cliproxyapi` user and group
- Create `/var/lib/cliproxyapi` for data storage
- Copy `config.example.yaml` to the data directory on first run
- Start the service on port 8317

### Custom Config File

```nix
{
  services.cliproxyapi = {
    enable = true;
    configFile = /path/to/your/config.yaml;
  };
}
```

### Git Storage Backend

Sync configuration and auth tokens with a Git repository:

```nix
{
  services.cliproxyapi = {
    enable = true;

    managementPasswordFile = "/run/secrets/cliproxyapi-management-password";

    storage = {
      type = "git";
      git = {
        url = "https://github.com/youruser/cliproxyapi-config.git";
        username = "youruser";
        tokenFile = "/run/secrets/github-token";
      };
    };
  };
}
```

### PostgreSQL Storage Backend

Store configuration in PostgreSQL:

```nix
{
  services.cliproxyapi = {
    enable = true;

    managementPasswordFile = "/run/secrets/cliproxyapi-management-password";

    storage = {
      type = "postgres";
      postgres = {
        dsnFile = "/run/secrets/postgres-dsn";  # Contains: postgresql://user:pass@host:5432/db
        schema = "cliproxyapi";
      };
    };
  };
}
```

### S3 Storage Backend

Store configuration in S3-compatible object storage:

```nix
{
  services.cliproxyapi = {
    enable = true;

    managementPasswordFile = "/run/secrets/cliproxyapi-management-password";

    storage = {
      type = "s3";
      s3 = {
        endpoint = "https://s3.amazonaws.com";
        bucket = "my-cliproxyapi-config";
        accessKeyFile = "/run/secrets/s3-access-key";
        secretKeyFile = "/run/secrets/s3-secret-key";
      };
    };
  };
}
```

## nix-darwin Configuration

### Basic Setup

```nix
{ inputs, ... }:

{
  imports = [ inputs.cliproxyapi.darwinModules.default ];

  services.cliproxyapi = {
    enable = true;
  };
}
```

The darwin module supports the same storage options as the NixOS module.

## Configuration

This flake intentionally does **not** manage `config.yaml` because:

1. CLIProxyAPI configuration is complex and highly variable
2. The Web UI provides an excellent configuration experience
3. The Desktop GUI (EasyCLI) offers another way to configure
4. Remote storage backends (Git, PostgreSQL, S3) allow configuration management outside of Nix

After starting the service, you can:

1. Access the Web UI at `http://localhost:8317`
2. Edit `/var/lib/cliproxyapi/config.yaml` directly
3. Use remote storage to manage configuration

See the [CLIProxyAPI documentation](https://help.router-for.me/) for configuration details.

## Module Options

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `enable` | bool | false | Enable the CLIProxyAPI service |
| `package` | package | (from flake) | The CLIProxyAPI package to use |
| `port` | port | 8317 | Port for CLIProxyAPI to listen on |
| `dataDir` | path | /var/lib/cliproxyapi | Directory for data storage |
| `configFile` | path or null | null | Path to config.yaml (optional) |
| `storage.type` | enum | "local" | Storage backend: local, git, postgres, s3 |
| `managementPasswordFile` | path or null | null | File with management UI password |
| `extraEnvironment` | attrs | {} | Extra environment variables |

### NixOS-specific

| Option | Type | Default | Description |
|--------|------|---------|-------------|
| `openFirewall` | bool | false | Open firewall for CLIProxyAPI port |
| `user` | string | "cliproxyapi" | User account for the service |
| `group` | string | "cliproxyapi" | Group for the service |

## Using the Overlay

You can also use the package via the overlay:

```nix
{
  nixpkgs.overlays = [ inputs.cliproxyapi.overlays.default ];

  environment.systemPackages = [ pkgs.cliproxyapi ];
}
```

## Automatic Updates

This repository includes a GitHub Action that checks for new CLIProxyAPI releases daily and creates PRs with updated version and hashes.

To manually trigger an update:
1. Go to Actions -> "Update CLIProxyAPI Version"
2. Click "Run workflow"
3. Optionally specify a version, or leave empty for latest

## License

MIT License - see [LICENSE](LICENSE)

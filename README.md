# nixos-config

This repository contains my personal configuration files for [NixOS](https://nixos.org/), a Linux distribution known for its declarative configuration and reliable system management.

## Description

This project serves as a comprehensive setup for my NixOS system. The configuration files in this repository are designed to:
- Simplify the management of system settings, packages, and services.
- Enable reproducibility across systems with ease.
- Provide a modular and structured approach to NixOS configuration.

## Repository Structure

The repository is structured to ensure clarity and modularity. Here’s a brief overview:

```
nixos-config/
├── flake.nix                       # Flake entry point
├── flake.lock                      # Flake lock file (auto-generated)
├── hosts/
│   └── home-server/
│       ├── configuration.nix       # Host-specific system config (imported in flake.nix)
│       └── hardware-configuration.nix  # Auto-generated hardware config
├── modules/
│   ├── common/                     # Reusable modules (e.g., user setup, firewall) 
│   └── services/                   # Service modules (e.g., openssh, jellyfin) 
├── packages/                       # Custom derivations or overlays 
├── devshell/                       # Custom development shells (with `nix develop`) 
└── README.md                       # Project documentation 
```

- **`hardware-configuration.nix`**: System-specific hardware settings.
- **`configuration.nix`**: The core configuration file that imports other modules and defines the overall system.
- **`modules/`**: Custom modules for splitting configurations by functionality (e.g., networking, user settings, etc.).
- **`packages/`**: Custom package overlays or definitions.

## Features

- **Declarative System Configuration**: Easily manage and version system configurations.
- **Reproducibility**: Reuse the same configuration across multiple systems.
- **Customizability**: Modular design allows for adaptability to different use cases.

## TODO
- [X] Secret management with sops-nix
- [X] nginx reverse proxy
- [ ] ACME for https
- [ ] Proxy from service options
- [X] cockpit web interface
- [ ] ail2Ban: Add Fail2Ban to protect against brute-force attacks
- [ ] automated Backups: restic or borg
- [ ] Monitoring: Grafana, Prometheus, or Zabbix
- [X] Enable and disable services more flexibly
- [ ] User name and info from file
- [X] Wifi from sops
- [ ] WireGuard + qbittorrent
- [ ] [Port forwarding](https://github.com/tenseiken/docker-qbittorrent-wireguard/blob/d3ad09a0551194f5d2efc35e637b248d380d6ff7/qbittorrent/portfwd.sh
) 
- [ ] Services sonarr, radarr, wizarr, jellyseerr, prowlarr 
## Getting Started

### Prerequisites

- A system running [NixOS](https://nixos.org/).
- Familiarity with the Nix language and NixOS configuration.

### Installation

1. Clone this repository:
   ```bash
   git clone https://github.com/Julien9969/nixos-config.git
   cd nixos-config
   ```

2. Copy or symlink the configurations to `/etc/nixos`:
   ```bash
   sudo cp -r * /etc/nixos/
   ```

3. Rebuild your NixOS system:
   ```bash
   sudo nixos-rebuild switch
   ```

## Sops-nix secret management
Create age key from ssh key:

```bash
sudo mkdir -p /var/lib/sops-nix
nix-shell -p ssh-to-age --run "ssh-to-age -private-key -i ~/.ssh/id_ed25519 > /var/lib/sops-nix/keys.txt"
```

Get the public key:
```bash
nix-shell -p age --run "age-keygen -y /var/lib/sops-nix/keys.txt"

or

nix-shell -p ssh-to-age --run "ssh-to-age < ~/.ssh/id_ed25519.pub"
```

You can use the `sops` command to manage your secrets. For example, to edit a secret file:
```bash
nix-shell -p sops --run "sops secrets/secrets.yaml" 

or 

sops-edit # (alias)
```


If you add a new host to your .sops.yaml file, you will need to update the keys for all secrets that are used by the new host. This can be done like so:
```bash
nix-shell -p sops --run "sops updatekeys secrets/secrets.yaml"
```

## Private secret git repository
To securely access a private secrets repository from your NixOS host, follow these steps:

#### 1. Start the SSH agent and add your key

```bash
eval "$(ssh-agent -s)"
ssh-add ~/.ssh/id_ed25519
```

#### 2. Configure your SSH client

Edit `~/.ssh/config` to add:

## Root login enable (openssh conf) ?

```ssh
Host nixserver
   HostName 192.168.1.150
   User root
   ForwardAgent yes
   IdentityFile ~/.ssh/id_ed25519
```

#### 3. Connect to your server with agent forwarding

```bash
ssh nixserver
```

#### 4. Test GitHub access from the server

```bash
ssh -T git@github.com
# You should see: "Hi Julien9969! You've successfully authenticated…"
```

### 5. Refresh secrets from the repository
```bash
nix flake update # update all
or 
nix flake update nix-private
```


### Adding a Module

To add a new module:
1. Create a `.nix` file under the `modules/` directory.
2. Import the module in `configuration.nix`:
   ```nix
   imports = [
     ./modules/<module-name>.nix
   ];
   ```

### Adding Custom Packages

To define custom packages:
1. Add package definitions under the `packages/` directory.
2. Include the packages in your system configuration.

## Contributing

If you have suggestions or improvements, feel free to open an issue or submit a pull request.

## License

This repository does not contain a specific license. Please reach out if you wish to use or adapt these configurations.


## Ressources
https://github.com/notthebee/nix-config/blob/94ec3a147f93d4f017fbde6e7e961569b48aff4d/homelab/services/wireguard-netns/default.nix
https://www.samkwort.com/qbittorrent_nixos_module
https://github.com/tenseiken/docker-qbittorrent-wireguard/blob/d3ad09a0551194f5d2efc35e637b248d380d6ff7/qbittorrent/portfwd.sh
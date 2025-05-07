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
- [ ] Secret management with sops-nix
- [ ] nginx reverse proxy
- [ ] ACME for https

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

## Customization

Feel free to modify the configuration files to suit your needs. The modular structure allows you to easily add, remove, or adjust specific aspects of the system.

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

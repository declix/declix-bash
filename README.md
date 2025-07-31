# declix-bash

A Bash script generator for declarative Linux system configuration using [Pkl](https://pkl-lang.org). Transform declarative resource definitions into idempotent shell scripts that can check, diff, and apply system configurations.

## Overview

declix-bash is part of the Declix ecosystem for declarative Linux configuration management. It takes resource definitions written in Pkl and generates safe, idempotent Bash scripts that can manage your system state.

### Key Features

- **Declarative Configuration**: Define desired system state in `.pkl` files
- **Idempotent Operations**: Scripts can be run repeatedly without side effects
- **Three Operation Modes**: `check`, `diff`, and `apply`
- **Safety First**: Generated scripts use strict error handling (`set -euo pipefail`)
- **Resource Types**: Support for packages, files, directories, systemd units, users, and groups
- **Content Validation**: SHA256 checksums for file content integrity

## Installation

### Download from GitHub Releases (Recommended)

Get the latest single-file release that works anywhere with just `pkl` and `bash`:

```bash
# Download the latest release
curl -L -o declix-bash.sh https://github.com/declix/declix-bash/releases/latest/download/declix-bash.sh
chmod +x declix-bash.sh

# Or with wget
wget https://github.com/declix/declix-bash/releases/latest/download/declix-bash.sh
chmod +x declix-bash.sh

# Verify installation
./declix-bash.sh --help
```

### Dependencies

declix-bash requires the following tools to generate scripts:

| Tool | Purpose | Installation |
|------|---------|-------------|
| **pkl** | Configuration language runtime | [Install guide](https://pkl-lang.org/main/current/pkl-cli/index.html) |
| **bash** | Shell interpreter (4.0+) | Pre-installed on most Linux distributions |

#### Quick Install with mise

If you have [mise](https://mise.jdx.dev/) installed, you can install all dependencies:

```bash
mise install pkl@latest
```

#### Manual Installation

**pkl**: Follow the [official installation guide](https://pkl-lang.org/main/current/pkl-cli/index.html)

**bash**: Usually pre-installed. Verify version with:
```bash
bash --version  # Should be 4.0 or higher
```

## Quick Start

Generate and execute scripts:

```bash
# Generate script (requires pkl)
./declix-bash.sh resources.pkl > generated-script.sh

# Execute on target system (no pkl required)
bash generated-script.sh check
bash generated-script.sh diff
bash generated-script.sh apply
```


## Resource Types

### APT Packages

```pkl
new apt.Package { 
    name = "nginx"
    state = "installed" 
    updateBeforeInstall = true
}
```

### Files and Directories

```pkl
new fs.File {
    path = "/etc/myapp/config.yml"
    state = new fs.FilePresent {
        content = "key: value"
        owner = "root"
        group = "root"
        permissions = "644"
    }
}

new fs.Directory {
    path = "/var/lib/myapp"
    state = new fs.DirectoryPresent {
        owner = "myapp"
        group = "myapp"
        permissions = "755"
    }
}
```

### Systemd Units

```pkl
new systemd.Unit {
    name = "nginx.service"
    state = new systemd.Enabled {
        active = true
        autoStart = true
    }
}
```

### Users and Groups

```pkl
new user.User {
    name = "webapp"
    state = new user.UserPresent {
        uid = 1001
        gid = 1001
        home = "/home/webapp"
        shell = "/bin/bash"
        comment = "Web application user"
    }
}
```

## Operation Modes

Generated scripts support three operation modes. You can either pipe directly or save to a file:

### Check Mode
Shows the current status of each resource:
```bash
# Direct execution
./generate.sh resources.pkl | bash -s check

# Or save and execute
./generate.sh resources.pkl > script.sh && bash script.sh check
```
Output shows "ok", "needs update", "needs creation", etc.

### Diff Mode
Shows detailed differences between current and desired state:
```bash
# Direct execution  
./generate.sh resources.pkl | bash -s diff

# Or save and execute
./generate.sh resources.pkl > script.sh && bash script.sh diff
```
Displays file content diffs, permission changes, etc.

### Apply Mode
Makes changes to achieve the desired state:
```bash
# Direct execution
./generate.sh resources.pkl | bash -s apply

# Or save and execute  
./generate.sh resources.pkl > script.sh && bash script.sh apply
```
Only makes necessary changes, reports what was modified.

## Example Configuration

```pkl
import "package://pkl.declix.org/pkl-declix@0.6.0#/apt/apt.pkl"
import "package://pkl.declix.org/pkl-declix@0.6.0#/fs/fs.pkl"
import "package://pkl.declix.org/pkl-declix@0.6.0#/systemd/systemd.pkl"

resources = new Listing {
    // Install required packages
    new apt.Package { 
        name = "nginx"
        state = "installed" 
    }
    
    // Create configuration file
    new fs.File {
        path = "/etc/nginx/sites-available/mysite"
        state = new fs.FilePresent {
            content = """
                server {
                    listen 80;
                    server_name example.com;
                    root /var/www/html;
                }
                """
            owner = "root"
            group = "root"
            permissions = "644"
        }
    }
    
    // Enable and start nginx
    new systemd.Unit {
        name = "nginx.service"
        state = new systemd.Enabled {
            active = true
            autoStart = true
        }
    }
}
```

## Development Commands

```bash
# Install development dependencies
just deps

# Build container image
just build

# Generate script locally (for development)
just generate-local resources.pkl

# Run tests
just test

# Run shellcheck on scripts
just shellcheck

# Create single-file release
just release

# Run all commit checks
just check-commit
```

### Alternative Development Methods

#### Build from Source

For development or to get the latest unreleased features:

```bash
# Clone the repository
git clone https://github.com/declix/declix-bash.git
cd declix-bash

# Install dependencies (pkl, shellcheck, etc.)
just deps

# Build single-file release
just release

# Use the built release
./out/declix-bash.sh resources.pkl > generated-script.sh
```

#### Using Local Development

For working on declix-bash itself:

```bash
# Generate script directly (requires pkl)
./generate.sh resources.pkl > generated-script.sh

# Execute generated script (no pkl required)
bash generated-script.sh check
bash generated-script.sh apply
```

#### Using Container

For isolated generation without installing Pkl locally:

```bash
# Build container (includes pkl)
just build

# Generate script using container
just generate resources.pkl > generated-script.sh

# Execute generated script on host (no pkl required)
bash generated-script.sh check
```

## Architecture

### Two-Phase Design

declix-bash uses a two-phase architecture that separates generation from execution:

**Phase 1: Script Generation** (Development/CI environment)
- Input: Pkl resource definitions (`.pkl` files)
- Processor: `generate.pkl` template engine  
- Dependencies: Pkl runtime, development tools
- Output: Self-contained bash script

**Phase 2: Script Execution** (Target systems)
- Input: Generated bash script
- Processor: Standard bash interpreter
- Dependencies: Only bash + system utilities
- Output: Applied system configuration

### Code Generation Flow

1. **Parse**: Pkl evaluates resource definitions and imports
2. **Transform**: `generate.pkl` converts resources to bash functions
3. **Embed**: File content encoded as base64, checksums calculated
4. **Package**: Single script with all dependencies embedded
5. **Execute**: Generated script runs independently on target systems

### Generated Script Structure

- **Header**: Strict error handling (`set -euo pipefail`)
- **Common Functions**: Reusable utilities from `src/common.sh`
- **Resource Functions**: One function per resource (named `_<sanitized_id>`)
- **Operation Handlers**: `check()`, `diff()`, `apply()` functions
- **Main Logic**: Command-line argument parsing and dispatch

### Safety Features

- **Input Sanitization**: All user input is properly quoted and escaped
- **Privilege Escalation**: Automatic `sudo` usage for privileged operations
- **Content Validation**: SHA256 checksums verify file content integrity
- **Idempotent Operations**: Check before modify pattern prevents unnecessary changes
- **Error Handling**: Strict bash settings catch errors early

## Testing

The project uses container-based integration tests:

```bash
# Run all tests
just test

# Run specific test
cd tests && just test-one files

# Test release build
just test-release
```

Test structure:
- Each test has a `resources.pkl` defining desired state
- `setup.sh` creates initial conditions
- `verify.sh` checks final state matches expectations
- Tests run in isolated containers

## File Handling

Files use a sophisticated content management system:

- **Content Sources**: String literals, external files, or URLs
- **Encoding**: Base64 encoding for binary compatibility
- **Validation**: SHA256 checksums ensure integrity
- **Atomicity**: Content written to temp files, then moved into place
- **Permissions**: Owner, group, and mode managed separately from content

## Related Projects

- **[pkl-declix](https://github.com/declix/pkl-declix)**: Core Pkl schemas for Linux resources
- **[declix-scraper](../declix-scraper)**: Generate Pkl configurations from existing systems
- **[pkl-systemd](../pkl-systemd)**: Pkl templates for systemd unit files

## Requirements

### Script Generation (Development Time)

Required for generating bash scripts from Pkl configurations:

- **pkl**: Apple's configuration language runtime ([install guide](https://pkl-lang.org/main/current/pkl-cli/index.html))
- **bash**: Modern bash shell (4.0+) for running `generate.sh`
- **Optional tools**:
  - **mise**: Tool version manager ([install guide](https://mise.jdx.dev/getting-started.html))
  - **just**: Task runner for development commands ([install guide](https://just.systems/man/en/chapter_1.html))
  - **shellcheck**: Bash linter for development
  - **podman/docker**: For container-based generation

### Script Execution (Runtime)

Required on target systems where generated scripts will run:

- **bash**: Modern bash shell (4.0+)
- **sudo**: For privileged operations (file management, package installation, etc.)
- **System utilities** (available on most Linux distributions):
  - `systemctl` - systemd service management
  - `apt-get`, `dpkg-query` - Debian/Ubuntu package management
  - `useradd`, `userdel`, `usermod` - user management
  - `groupadd`, `groupdel`, `groupmod`, `gpasswd` - group management
  - `stat`, `sha256sum`, `chown`, `chmod` - file operations
  - Standard POSIX utilities: `mkdir`, `cp`, `rm`, `diff`, etc.

### Architecture: Generation vs Execution

**Generation Side** (where you develop and generate scripts):
- Requires Pkl runtime and development tools
- Processes `.pkl` configuration files
- Produces standalone bash scripts
- Can run in containers for isolation

**Execution Side** (target systems):
- Only needs bash and standard Linux utilities
- No Pkl dependency required
- Generated scripts are self-contained
- Scripts include embedded content and checksums

## License

See [LICENSE](LICENSE) file for details.
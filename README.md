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

## Quick Start

### Using the Release Build (Recommended)

Download or build the single-file release:

```bash
# Build the release
just release

# Use the single-file script
./out/declix-bash.sh resources.pkl | bash -s check
./out/declix-bash.sh resources.pkl | bash -s diff
./out/declix-bash.sh resources.pkl | bash -s apply
```

### Using Local Development

```bash
# Install dependencies
just deps

# Generate and run scripts
./generate.sh resources.pkl | bash -s check
./generate.sh resources.pkl | bash -s apply
```

### Using Container

```bash
# Build container
just build

# Generate using container
just generate resources.pkl | bash -s check
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

### Check Mode
Shows the current status of each resource:
```bash
./generate.sh resources.pkl | bash -s check
```
Output shows "ok", "needs update", "needs creation", etc.

### Diff Mode
Shows detailed differences between current and desired state:
```bash
./generate.sh resources.pkl | bash -s diff
```
Displays file content diffs, permission changes, etc.

### Apply Mode
Makes changes to achieve the desired state:
```bash
./generate.sh resources.pkl | bash -s apply
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

# Generate script locally
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

## Architecture

### Code Generation Flow

1. **Input**: Pkl resource definitions (`.pkl` files)
2. **Processing**: `generate.pkl` transforms resources into Bash functions
3. **Output**: Self-contained shell script with embedded functions
4. **Execution**: Generated script supports check/diff/apply operations

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

- **pkl**: Apple's configuration language runtime
- **bash**: Modern bash shell (4.0+)
- **sudo**: For privileged system operations
- **Standard utilities**: `systemctl`, `apt-get`, `useradd`, etc.

## License

See [LICENSE](LICENSE) file for details.
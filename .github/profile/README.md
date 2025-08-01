# Declix - Declarative Linux Configuration

<div align="center">

**Transform declarative resource definitions into idempotent system configurations**

[![Pkl](https://img.shields.io/badge/Pkl-Configuration%20Language-blue)](https://pkl-lang.org)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

</div>

## Overview

Declix brings declarative configuration management to Linux systems using [Pkl](https://pkl-lang.org) (Apple's configuration language). Define your desired system state in human-readable configuration files and let Declix generate safe, idempotent scripts to achieve that state.

## Fundamental Principles

### 1. **Declarative Over Imperative**
Define *what* you want, not *how* to get there. Describe the desired end state of your system resources, and Declix handles the implementation details.

```pkl
// Declare desired state
new apt.Package { 
    name = "nginx"
    state = "installed" 
}

// Not imperative commands
// ❌ sudo apt-get update && sudo apt-get install nginx
```

### 2. **Type-Safe Configuration**
Leverage Pkl's strong type system to catch configuration errors before deployment. No more runtime surprises from typos or invalid values.

### 3. **Idempotent Operations**
Generated scripts can run multiple times safely. They check current state, show diffs, and only make necessary changes.

```bash
# Safe to run repeatedly
./generated-script.sh check   # What needs changing?
./generated-script.sh diff    # Show exact differences
./generated-script.sh apply   # Make only required changes
```

### 4. **Two-Phase Architecture**
Separate configuration time (requires Pkl) from execution time (requires only bash). Generate scripts in CI/CD, execute anywhere.

### 5. **Composable Resources**
Build complex configurations from simple, reusable resource definitions. Mix and match packages, files, services, users, and more.

## Projects Under the Declix Umbrella

### 🔧 [pkl-declix](https://github.com/declix/pkl-declix)
Core Pkl schemas defining Linux resource types. The foundation for all declarative configurations.
- APT/DPKG package management
- File and directory resources
- User and group management
- Systemd service control

### 🚀 [declix-bash](https://github.com/declix/declix-bash)
Transforms Pkl configurations into portable bash scripts. The workhorse that generates idempotent deployment scripts.
- Generates self-contained bash scripts
- No runtime dependencies beyond bash
- Built-in safety with checksums and validation
- Available as container: `ghcr.io/declix/declix-bash`

### 🔍 [declix-scraper](https://github.com/declix/declix-scraper)
Discover existing system state and generate Pkl configurations. Perfect for migrating existing systems to declarative management.
- Scan installed packages
- Capture file contents and permissions
- Export systemd service configurations
- Generate ready-to-use Pkl files

### 📦 [pkl-systemd](https://github.com/declix/pkl-systemd)
Specialized Pkl templates for systemd unit files. Type-safe systemd configuration with validation.
- Service units with dependency management
- Timer units for scheduled tasks
- Socket units for activation
- Mount units for filesystem management

## Getting Started

### Step 1: Write Your Configuration

Create a `resources.pkl` file describing your desired system state:

```pkl
import "package://pkl.declix.org/pkl-declix@0.6.0#/apt/apt.pkl"
import "package://pkl.declix.org/pkl-declix@0.6.0#/fs/fs.pkl"
import "package://pkl.declix.org/pkl-systemd@0.1.2#/service.pkl" as systemd

resources = new Listing {
    // Install web server
    new apt.Package { 
        name = "nginx"
        state = "installed" 
    }
    
    // Configure site
    new fs.File {
        path = "/etc/nginx/sites-available/myapp"
        state = new fs.FilePresent {
            content = """
                server {
                    listen 80;
                    server_name myapp.local;
                    root /var/www/myapp;
                    index index.html;
                }
                """
            owner = "root"
            group = "root"
            permissions = "644"
        }
    }
    
    // Create web root
    new fs.Directory {
        path = "/var/www/myapp"
        state = new fs.DirectoryPresent {
            owner = "www-data"
            group = "www-data"
            permissions = "755"
        }
    }
    
    // Enable and start service
    new systemd.Service {
        name = "nginx"
        enabled = true
        state = "started"
    }
}
```

### Step 2: Generate Deployment Script

Use declix-bash to transform your configuration into an executable script:

```bash
# Using container (no local installation required)
podman run --rm \
    -v ./resources.pkl:/work/resources.pkl:ro \
    ghcr.io/declix/declix-bash:latest \
    /work/resources.pkl > deploy.sh

# Or with local installation
curl -L -o declix-bash.sh \
    https://github.com/declix/declix-bash/releases/latest/download/declix-bash.sh
chmod +x declix-bash.sh
./declix-bash.sh resources.pkl > deploy.sh
```

### Step 3: Deploy to Target Systems

Execute the generated script on your target systems:

```bash
# Check what would change
bash deploy.sh check

# See detailed differences
bash deploy.sh diff

# Apply configuration
bash deploy.sh apply
```

## Migration Path: From Existing to Declarative

Use declix-scraper to capture your current system state:

```bash
# Scan existing system
podman run --rm \
    -v /etc:/etc:ro \
    -v ./output:/output \
    ghcr.io/declix/declix-scraper:latest \
    --packages --files /etc/nginx --services nginx

# Review generated configuration
cat output/discovered-resources.pkl

# Customize and deploy
podman run --rm \
    -v ./output/discovered-resources.pkl:/work/resources.pkl:ro \
    ghcr.io/declix/declix-bash:latest \
    /work/resources.pkl | bash -s apply
```

## Real-World Example: Complete Web Application Stack

```pkl
import "package://pkl.declix.org/pkl-declix@0.6.0#/resources.pkl" as res
import "package://pkl.declix.org/pkl-systemd@0.1.2#/service.pkl" as systemd

resources = new Listing {
    // System packages
    for (pkg in List("postgresql-14", "nginx", "redis-server", "python3-pip")) {
        new res.AptPackage { 
            name = pkg
            state = "installed" 
        }
    }
    
    // Application user
    new res.User {
        name = "myapp"
        state = new res.UserPresent {
            home = "/opt/myapp"
            shell = "/bin/bash"
            comment = "Application User"
        }
    }
    
    // Application files
    new res.File {
        path = "/opt/myapp/config.json"
        state = new res.FilePresent {
            content = """
                {
                    "database": "postgresql://localhost/myapp",
                    "redis": "redis://localhost:6379/0",
                    "port": 8000
                }
                """
            owner = "myapp"
            group = "myapp"
            permissions = "600"
        }
    }
    
    // Systemd service
    new systemd.Service {
        name = "myapp"
        description = "My Application"
        exec_start = "/opt/myapp/venv/bin/python -m myapp"
        user = "myapp"
        group = "myapp"
        working_directory = "/opt/myapp"
        restart = "always"
        
        environment = new Mapping {
            ["CONFIG_FILE"] = "/opt/myapp/config.json"
        }
        
        enabled = true
        state = "started"
    }
}
```

## Why Declix?

- **Safety First**: Generated scripts use strict error handling and validate changes before applying
- **GitOps Ready**: Configuration as code that's version controlled, reviewed, and tested
- **No Agent Required**: No daemon, no runtime dependencies, just bash scripts
- **Container Native**: All tools available as containers for easy CI/CD integration
- **Progressive Adoption**: Start with one service, expand as needed
- **Existing System Friendly**: Scraper helps migrate current configurations

## Community and Support

- 📚 [Documentation](https://github.com/declix/pkl-declix/wiki)
- 🐛 [Report Issues](https://github.com/declix/pkl-declix/issues)
- 💬 [Discussions](https://github.com/declix/pkl-declix/discussions)
- 🤝 [Contributing Guidelines](https://github.com/declix/.github/blob/main/CONTRIBUTING.md)

## License

All Declix projects are released under the MIT License. See individual repositories for details.

---

<div align="center">

**Start declaratively managing your Linux systems today!**

[Get Started with pkl-declix](https://github.com/declix/pkl-declix) | [Try declix-bash](https://github.com/declix/declix-bash) | [Explore Examples](https://github.com/declix/pkl-declix/tree/main/examples)

</div>
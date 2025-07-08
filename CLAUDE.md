# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Overview

declix-bash is a Bash script generator for declarative Linux system configuration. It uses Pkl (Apple's configuration language) to generate idempotent Bash scripts that can check, diff, and apply system configurations.

## Core Architecture

The system follows a code generation pattern:
1. Users define resources in `.pkl` files (e.g., APT packages, files)
2. `generate.pkl` transforms these declarations into Bash functions
3. Generated scripts support three actions: `check`, `diff`, and `apply`

Key files:
- `generate.pkl`: Main Pkl template that orchestrates script generation
- `src/common.sh`: Reusable Bash functions for resource management
- `generate.sh`: Shell wrapper that invokes Pkl with proper imports

## Common Commands

```bash
# Check system state against desired configuration
./generate.sh resources.pkl | bash -s check

# Apply configuration changes
./generate.sh resources.pkl | bash -s apply

# Show differences between current and desired state
./generate.sh resources.pkl | bash -s diff

# Debug Pkl evaluation directly
pkl eval resources.pkl
```

## Development Patterns

### Adding New Resource Types

1. Extend the generator in `generate.pkl`:
   - Add a new `toGen()` function clause for your resource type
   - Create a `Gen` object with appropriate Bash code generation

2. Add supporting functions in `src/common.sh` if needed

3. The generated function should handle all three actions: check, diff, apply

### Resource Function Naming

Functions are named by sanitizing resource IDs:
- Replace special characters with underscores
- Prefix with "r_" to ensure valid Bash function names

### File Content Handling

Files use SHA256 checksums and base64 encoding:
- Content is validated before applying changes
- Binary files are supported through base64 encoding
- Ownership and permissions are managed separately from content

## Testing Approach

No formal test suite exists. Test changes by:
1. Creating a test `.pkl` file with resource definitions
2. Running the generator and inspecting output
3. Testing generated scripts in a safe environment

## Important Implementation Details

- All generated scripts use `set -eu` and `set -o pipefail` for safety
- Sudo is used automatically when needed for privileged operations
- Resource operations are idempotent - check before apply
- The generator sanitizes all user input to prevent Bash injection
- File paths and content are properly quoted in generated scripts

## Related Projects

- pkl-declix can be found here: https://github.com/declix/pkl-declix
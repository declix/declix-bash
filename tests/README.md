# declix-bash Tests

This directory contains the test suite for declix-bash. Each test runs in an isolated container to ensure reproducibility and safety.

## Test Structure

Each test is a self-contained directory containing:

- `resources.pkl` (required) - The Pkl resource definitions to test
- `setup.sh` (optional) - Script to prepare the test environment before generation
- `verify.sh` (optional) - Script to verify the test results after generation

### Test Execution Flow

1. Build a container with all dependencies (pkl, mise, etc.)
2. For each test directory:
   - Run `setup.sh` if present (with sudo privileges) to prepare environment
   - Generate bash script using `generate.sh resources.pkl > generated.sh`
   - Check syntax with `bash -n generated.sh`
   - Run `bash generated.sh check` to see initial state
   - Run `sudo bash generated.sh apply` to apply changes
   - Run `bash generated.sh check > final_state.txt` to capture final state
   - Run `verify.sh` if present to verify all resources show "ok" status

## Available Tests

### `empty/`
Tests that an empty resource list generates a valid bash script with proper structure.

### `packages/`
Tests APT package management:
- Detection of installed packages (curl)
- Detection of missing packages (wget)
- Handling of packages marked for removal (nonexistent-package with state="missing")

### `files/`
Tests file management:
- File creation with content, ownership, and permissions
- File removal (state="missing")
- Detection of files needing updates (wrong content/permissions)

## Running Tests

From the tests directory:

```bash
# Run all tests
just test

# Run a specific test
just test-one packages

# Debug a test with verbose output
just test-debug files

# Open interactive shell in test container
just test-interactive

# Clean up test artifacts
just clean
```

## Writing New Tests

1. Create a new directory for your test:
   ```bash
   mkdir mytest
   ```

2. Create `resources.pkl` with the resources to test:
   ```pkl
   import "package://pkl.declix.org/pkl-declix@0.3.0#/apt/apt.pkl"
   
   resources = new Listing {
       new apt.Package { 
           name = "vim"
           state = "installed" 
       }
   }
   ```

3. (Optional) Create `setup.sh` to prepare the environment:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Setting up test environment..."
   apt-get update
   apt-get install -y vim
   ```

4. (Optional) Create `verify.sh` to verify final state:
   ```bash
   #!/bin/bash
   set -euo pipefail
   
   echo "Verifying resource statuses..."
   
   # Check that all resources show "ok" status
   if ! grep -q "^apt:vim.*ok$" final_state.txt; then
       echo "ERROR: vim is not in 'ok' state"
       cat final_state.txt
       exit 1
   fi
   
   # Optionally verify actual system state
   if ! command -v vim >/dev/null 2>&1; then
       echo "ERROR: vim should be installed"
       exit 1
   fi
   
   echo "✓ Test passed"
   ```

## Test Container

The test container (defined in `Containerfile`) is based on Debian 12 and includes:
- Basic tools (curl, git, sudo)
- mise for version management
- pkl (installed via mise)
- just for task running
- A non-root user with sudo access

Each test runs in a fresh container instance to ensure complete isolation.

## Best Practices

1. **Keep tests focused** - Each test should verify one specific aspect
2. **Use meaningful names** - Test directory names should describe what's being tested
3. **Clean up in setup** - Ensure setup.sh creates a predictable starting state
4. **Check both positive and negative cases** - Verify both what should and shouldn't happen
5. **Use clear error messages** - Help diagnose failures quickly

## Troubleshooting

If a test fails:

1. Run the specific test to see output:
   ```bash
   just test-one failing-test
   ```

2. Use debug mode for detailed execution trace:
   ```bash
   just test-debug failing-test
   ```

3. Open an interactive shell to investigate:
   ```bash
   just test-interactive
   # Then inside the container:
   cd failing-test
   bash -x ../run-test.sh .
   ```
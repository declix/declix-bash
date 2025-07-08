#!/bin/bash
set -euo pipefail

echo "Setting up directories test environment..."

# Create a directory that should be detected as existing but with wrong permissions
mkdir -p /tmp/test-dir-1
chown root:root /tmp/test-dir-1
chmod 700 /tmp/test-dir-1

# Create a directory that should be removed
mkdir -p /tmp/test-dir-2

# Ensure test-config-dir doesn't exist yet
rm -rf /tmp/test-config-dir

echo "✓ Directories test setup complete"
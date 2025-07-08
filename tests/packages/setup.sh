#!/bin/bash
set -euo pipefail

echo "Setting up packages test environment..."

# Ensure curl is installed for testing
apt-get update > /dev/null 2>&1
apt-get install -y curl > /dev/null 2>&1

# Ensure wget is NOT installed (so we can test installation detection)
apt-get remove -y wget > /dev/null 2>&1 || true

echo "✓ Package test setup complete"
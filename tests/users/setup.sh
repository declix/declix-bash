#!/bin/bash
set -euo pipefail

echo "Setting up user test environment..."

# Ensure we're running with proper permissions for user management
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: User tests need to run as root for user/group management"
    exit 1
fi

# Clean up any existing test users/groups from previous runs
userdel -r testuser1 2>/dev/null || true
userdel -r testsrv 2>/dev/null || true
groupdel testgroup 2>/dev/null || true
groupdel testsrv 2>/dev/null || true

echo "✓ User test setup completed"
#!/bin/bash
set -euo pipefail

echo "Setting up files test environment..."

# Create a file that should be detected as existing but with wrong content
echo "wrong content" > /tmp/test-file-1.txt
chown root:root /tmp/test-file-1.txt
chmod 755 /tmp/test-file-1.txt

# Create a file that should be removed
echo "should be removed" > /tmp/test-file-2.txt

# Ensure test-config.conf doesn't exist yet
rm -f /tmp/test-config.conf

echo "✓ Files test setup complete"
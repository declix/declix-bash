#!/bin/bash
set -euo pipefail

echo "Setting up systemd test environment..."

# Ensure we're running with proper permissions
if [ "$EUID" -ne 0 ]; then
    echo "ERROR: Systemd tests need to run as root for systemd management"
    exit 1
fi

# Check if systemd is available
if ! command -v systemctl >/dev/null 2>&1; then
    echo "ERROR: systemctl not available - systemd tests require systemd"
    exit 1
fi

# Wait for systemd to be ready
echo "Waiting for systemd to be ready..."
for i in {1..30}; do
    if systemctl --version >/dev/null 2>&1; then
        echo "Systemd is ready"
        break
    fi
    echo "Waiting for systemd... ($i/30)"
    sleep 1
done

if ! systemctl --version >/dev/null 2>&1; then
    echo "ERROR: systemd is not responding after 30 seconds"
    exit 1
fi

# Clean up any existing test services from previous runs
echo "Cleaning up existing test services..."
systemctl stop test-app.service 2>/dev/null || true
systemctl stop test-backup.timer 2>/dev/null || true
systemctl stop test-backup.service 2>/dev/null || true
systemctl stop test-disabled.service 2>/dev/null || true
systemctl stop test-dependency.service 2>/dev/null || true
systemctl stop test-socket.socket 2>/dev/null || true
systemctl stop test-complex.service 2>/dev/null || true
systemctl stop tmp-testmount.mount 2>/dev/null || true

systemctl disable test-app.service 2>/dev/null || true
systemctl disable test-backup.timer 2>/dev/null || true
systemctl disable test-disabled.service 2>/dev/null || true
systemctl disable test-dependency.service 2>/dev/null || true
systemctl disable test-socket.socket 2>/dev/null || true
systemctl disable test-complex.service 2>/dev/null || true
systemctl disable tmp-testmount.mount 2>/dev/null || true

# Note: masked service cleanup removed - see issue #3

# Remove existing unit files
rm -f /etc/systemd/system/test-*.service
rm -f /etc/systemd/system/test-*.timer
rm -f /etc/systemd/system/test-*.socket
rm -f /etc/systemd/system/tmp-*.mount

# Clean up test artifacts
rm -f /tmp/backup-ran
umount /tmp/testmount 2>/dev/null || true
rm -rf /tmp/testmount

# Reload systemd to clean up
systemctl daemon-reload

echo "✓ Systemd test setup completed"
#!/bin/bash
set -euo pipefail

# Check final state file exists
if [ ! -f final_state.txt ]; then
    echo "ERROR: final_state.txt not found"
    exit 1
fi

echo "Verifying systemd test results..."

# All resources should show "ok" after apply
expected_resources=(
    "file:/etc/systemd/system/test-app.service"
    "file:/etc/systemd/system/test-backup.service"
    "file:/etc/systemd/system/test-backup.timer"
    "file:/etc/systemd/system/test-disabled.service"
    "file:/etc/systemd/system/test-dependency.service"
    "file:/etc/systemd/system/test-socket.socket"
    "file:/etc/systemd/system/test-socket.service"
    "file:/etc/systemd/system/tmp-testmount.mount"
    "file:/etc/systemd/system/test-complex.service"
    # Note: No file resource for test-masked.service - masking creates its own symlink
    "systemd:test-app.service"
    "systemd:test-backup.timer"
    "systemd:test-disabled.service"
    "systemd:test-dependency.service"
    "systemd:test-socket.socket"
    "systemd:tmp-testmount.mount"
    "systemd:test-complex.service"
    "systemd:test-removed.service"
)

for resource in "${expected_resources[@]}"; do
    if ! grep -q "^$resource.*ok$" final_state.txt; then
        echo "ERROR: Resource $resource is not in 'ok' state"
        echo "Final state:"
        cat final_state.txt
        exit 1
    fi
done

echo "✓ All resources in expected state"

# Verify actual systemd states
echo "Verifying systemd unit states..."

# Debug: Show systemd status
echo "=== Debug: systemctl status ==="
systemctl status --no-pager || true
echo "=== Debug: systemctl list-units ==="
systemctl list-units --all --no-pager | grep test || true
echo "=== Debug: systemctl list-unit-files ==="
systemctl list-unit-files --no-pager | grep test || true
echo "=== End Debug ==="

# Test that unit files exist
unit_files=(
    "/etc/systemd/system/test-app.service"
    "/etc/systemd/system/test-backup.service"
    "/etc/systemd/system/test-backup.timer"
    "/etc/systemd/system/test-disabled.service"
    "/etc/systemd/system/test-dependency.service"
    "/etc/systemd/system/test-socket.socket"
    "/etc/systemd/system/test-socket.service"
    "/etc/systemd/system/tmp-testmount.mount"
    "/etc/systemd/system/test-complex.service"
    # Note: test-masked.service will be a symlink to /dev/null after masking
)

for unit_file in "${unit_files[@]}"; do
    # For masked services, the file might be a symlink to /dev/null
    if [ ! -e "$unit_file" ]; then
        echo "ERROR: Unit file $unit_file should exist but doesn't"
        exit 1
    fi
    # Check if it's a masked service (symlink to /dev/null)
    if [ -L "$unit_file" ] && [ "$(readlink "$unit_file")" = "/dev/null" ]; then
        echo "Note: $unit_file is masked (symlink to /dev/null)"
    fi
done

echo "✓ All unit files exist"

# Note: Masked service test removed - see issue #3

# Verify service enable/disable states
echo "Verifying service states..."

# Services that should be enabled
enabled_units=(
    "test-app.service"
    "test-backup.timer"
    "test-dependency.service"
    "test-socket.socket"
    "tmp-testmount.mount"
    "test-complex.service"
)

for unit in "${enabled_units[@]}"; do
    if ! systemctl is-enabled "$unit" >/dev/null 2>&1; then
        echo "ERROR: Unit $unit should be enabled but isn't"
        systemctl status "$unit" || true
        exit 1
    fi
done

echo "✓ All expected services are enabled"

# Service that should be disabled
if systemctl is-enabled test-disabled.service >/dev/null 2>&1; then
    echo "ERROR: test-disabled.service should be disabled but is enabled"
    exit 1
fi

echo "✓ test-disabled.service is correctly disabled"

# Note: Masked service verification removed - see issue #3

# Verify active states for long-running services
active_services=(
    "test-app.service"
    "test-dependency.service"
    "test-complex.service"
)

for service in "${active_services[@]}"; do
    if ! systemctl is-active "$service" >/dev/null 2>&1; then
        echo "ERROR: Service $service should be active but isn't"
        systemctl status "$service" || true
        exit 1
    fi
done

echo "✓ All expected services are active"

# Verify socket is listening
if ! systemctl is-active test-socket.socket >/dev/null 2>&1; then
    echo "ERROR: test-socket.socket should be active but isn't"
    systemctl status test-socket.socket || true
    exit 1
fi

echo "✓ Socket is active"

# Verify mount is active
if ! systemctl is-active tmp-testmount.mount >/dev/null 2>&1; then
    echo "ERROR: tmp-testmount.mount should be active but isn't"
    systemctl status tmp-testmount.mount || true
    exit 1
fi

echo "✓ Mount is active"

# Verify mount point exists and has correct filesystem
if ! mountpoint -q /tmp/testmount; then
    echo "ERROR: /tmp/testmount should be a mount point but isn't"
    mount | grep testmount || true
    exit 1
fi

if ! df -T /tmp/testmount | grep -q tmpfs; then
    echo "ERROR: /tmp/testmount should be tmpfs but isn't"
    df -T /tmp/testmount
    exit 1
fi

echo "✓ Mount point is correctly mounted as tmpfs"

# Test timer functionality - verify the timer is active
if ! systemctl is-active test-backup.timer >/dev/null 2>&1; then
    echo "ERROR: test-backup.timer should be active but isn't"
    systemctl status test-backup.timer || true
    exit 1
fi

echo "✓ Timer is active"

# Check that services have correct content
echo "Verifying unit file content..."

# Check that test-app.service has correct content
if ! grep -q "Test Application Service" /etc/systemd/system/test-app.service; then
    echo "ERROR: test-app.service doesn't have expected description"
    exit 1
fi

if ! grep -q "Restart=always" /etc/systemd/system/test-app.service; then
    echo "ERROR: test-app.service doesn't have expected restart policy"
    exit 1
fi

echo "✓ Service files have correct content"

# Check that complex service has environment variables
if ! grep -q "Environment=" /etc/systemd/system/test-complex.service; then
    echo "ERROR: test-complex.service doesn't have environment variables"
    exit 1
fi

if ! grep -q "Environment=TEST_VAR=test_value" /etc/systemd/system/test-complex.service; then
    echo "ERROR: test-complex.service doesn't have expected environment variable"
    exit 1
fi

echo "✓ Complex service has correct environment configuration"

# Verify socket configuration
if ! grep -q "ListenStream=127.0.0.1:8080" /etc/systemd/system/test-socket.socket; then
    echo "ERROR: test-socket.socket doesn't have expected listen address"
    exit 1
fi

echo "✓ Socket has correct configuration"

# Verify timer configuration
if ! grep -q "OnCalendar=\\*:0/5" /etc/systemd/system/test-backup.timer; then
    echo "ERROR: test-backup.timer doesn't have expected schedule"
    exit 1
fi

echo "✓ Timer has correct schedule"

# Check that disabled service is stopped
if systemctl is-active test-disabled.service >/dev/null 2>&1; then
    echo "ERROR: test-disabled.service should be stopped but is active"
    exit 1
fi

echo "✓ Disabled service is correctly stopped"

# Verify that test-removed.service doesn't exist
if systemctl list-unit-files test-removed.service 2>/dev/null | grep -q test-removed.service; then
    echo "ERROR: test-removed.service should not exist but does"
    exit 1
fi

echo "✓ Removed service is correctly absent"

echo "✓ Systemd test verification completed successfully - all units configured correctly"
#!/bin/bash
set -euo pipefail

# Check final state file exists
if [ ! -f final_state.txt ]; then
    echo "ERROR: final_state.txt not found"
    exit 1
fi

# All directories should show "ok" after apply
expected_dirs="dir:/tmp/test-dir-1 dir:/tmp/test-dir-2 dir:/tmp/test-config-dir"

for dir in $expected_dirs; do
    if ! grep -q "^$dir.*ok$" final_state.txt; then
        echo "ERROR: Directory $dir is not in 'ok' state"
        echo "Final state:"
        cat final_state.txt
        exit 1
    fi
done

# Verify actual directory states
# test-dir-1 should exist with correct permissions
if [ ! -d /tmp/test-dir-1 ]; then
    echo "ERROR: /tmp/test-dir-1 should exist"
    exit 1
fi

# Check ownership and permissions
stat_output=$(stat -c "%U:%G %a" /tmp/test-dir-1)
if [ "$stat_output" != "nobody:nogroup 755" ]; then
    echo "ERROR: /tmp/test-dir-1 has wrong ownership/permissions: $stat_output"
    exit 1
fi

# test-dir-2 should NOT exist (state=missing)
if [ -d /tmp/test-dir-2 ]; then
    echo "ERROR: /tmp/test-dir-2 should not exist (state=missing)"
    exit 1
fi

# test-config-dir should exist with correct permissions
if [ ! -d /tmp/test-config-dir ]; then
    echo "ERROR: /tmp/test-config-dir should exist"
    exit 1
fi

stat_output=$(stat -c "%U:%G %a" /tmp/test-config-dir)
if [ "$stat_output" != "nobody:nogroup 750" ]; then
    echo "ERROR: /tmp/test-config-dir has wrong ownership/permissions: $stat_output"
    exit 1
fi

echo "✓ Directories test verified - all directories in correct state"
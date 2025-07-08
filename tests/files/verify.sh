#!/bin/bash
set -euo pipefail

# Check final state file exists
if [ ! -f final_state.txt ]; then
    echo "ERROR: final_state.txt not found"
    exit 1
fi

# All files should show "ok" after apply
expected_files="file:/tmp/test-file-1.txt file:/tmp/test-file-2.txt file:/tmp/test-config.conf"

for file in $expected_files; do
    if ! grep -q "^$file.*ok$" final_state.txt; then
        echo "ERROR: File $file is not in 'ok' state"
        echo "Final state:"
        cat final_state.txt
        exit 1
    fi
done

# Verify actual file states
# test-file-1.txt should exist with correct content
if [ ! -f /tmp/test-file-1.txt ]; then
    echo "ERROR: /tmp/test-file-1.txt should exist"
    exit 1
fi

if ! grep -q "This is a test file" /tmp/test-file-1.txt; then
    echo "ERROR: /tmp/test-file-1.txt has wrong content"
    exit 1
fi

# Check ownership and permissions
stat_output=$(stat -c "%U:%G %a" /tmp/test-file-1.txt)
if [ "$stat_output" != "nobody:nogroup 644" ]; then
    echo "ERROR: /tmp/test-file-1.txt has wrong ownership/permissions: $stat_output"
    exit 1
fi

# test-file-2.txt should NOT exist (state=missing)
if [ -f /tmp/test-file-2.txt ]; then
    echo "ERROR: /tmp/test-file-2.txt should not exist (state=missing)"
    exit 1
fi

# test-config.conf should exist with correct content and permissions
if [ ! -f /tmp/test-config.conf ]; then
    echo "ERROR: /tmp/test-config.conf should exist"
    exit 1
fi

stat_output=$(stat -c "%U:%G %a" /tmp/test-config.conf)
if [ "$stat_output" != "nobody:nogroup 600" ]; then
    echo "ERROR: /tmp/test-config.conf has wrong ownership/permissions: $stat_output"
    exit 1
fi

echo "✓ Files test verified - all files in correct state"
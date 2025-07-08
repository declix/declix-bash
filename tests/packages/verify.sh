#!/bin/bash
set -euo pipefail

# Check final state file exists
if [ ! -f final_state.txt ]; then
    echo "ERROR: final_state.txt not found"
    exit 1
fi

# All packages should show "ok" after apply
expected_packages="apt:curl apt:wget apt:nonexistent-package"

for pkg in $expected_packages; do
    if ! grep -q "^$pkg.*ok$" final_state.txt; then
        echo "ERROR: Package $pkg is not in 'ok' state"
        echo "Final state:"
        cat final_state.txt
        exit 1
    fi
done

# Verify actual system state
if ! command -v curl >/dev/null 2>&1; then
    echo "ERROR: curl should be installed but isn't found"
    exit 1
fi

if ! command -v wget >/dev/null 2>&1; then
    echo "ERROR: wget should be installed but isn't found"
    exit 1
fi

echo "✓ Package test verified - all packages in correct state"
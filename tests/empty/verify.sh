#!/bin/bash
set -euo pipefail

# For empty test, just verify the file exists and has no resources
if [ ! -f final_state.txt ]; then
    echo "ERROR: final_state.txt not found"
    exit 1
fi

# Should be empty or contain only whitespace
if [ -s final_state.txt ] && grep -q "[a-zA-Z]" final_state.txt; then
    echo "ERROR: Expected no resources, but found:"
    cat final_state.txt
    exit 1
fi

echo "✓ Empty test verified - no resources as expected"
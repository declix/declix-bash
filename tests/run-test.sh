#!/bin/bash
set -euo pipefail

# Run a single test directory
TEST_DIR="$1"
TEST_NAME=$(basename "$TEST_DIR")

echo "=== Running test: $TEST_NAME ==="

# Change to test directory
cd "$TEST_DIR"

# Ensure we can write to the test directory
if ! touch test_write_check 2>/dev/null; then
    echo "ERROR: Cannot write to test directory $TEST_DIR"
    ls -la "$TEST_DIR"
    exit 1
fi
rm -f test_write_check

# Run setup if exists
if [ -f setup.sh ]; then
    echo "Running setup..."
    chmod +x setup.sh
    bash setup.sh
fi

# Note: Script generation must be done by the host before running this container
# The generated.sh file should already exist in the mounted test directory
echo "Checking for generated script..."
if [ ! -f generated.sh ]; then
    echo "ERROR: generated.sh not found. Script must be generated before running test."
    exit 1
fi

# Check syntax
echo "Checking syntax..."
if ! bash -n generated.sh; then
    echo "ERROR: Syntax check failed"
    exit 1
fi

# Run check to see initial state
echo "Checking initial state..."
bash generated.sh check

# Run apply to make changes
echo "Applying changes..."
bash generated.sh apply

# Run check again to verify final state
echo "Checking final state..."
bash generated.sh check > final_state.txt

# Run verify if exists to check resource statuses
if [ -f verify.sh ]; then
    echo "Verifying resource statuses..."
    chmod +x verify.sh
    bash verify.sh
else
    echo "No verify.sh found, checking that all resources show 'ok'..."
    if grep -v "ok$" final_state.txt | grep -v "^$"; then
        echo "ERROR: Some resources are not in 'ok' state:"
        grep -v "ok$" final_state.txt | grep -v "^$"
        exit 1
    fi
    echo "✓ All resources are in 'ok' state"
fi

echo "=== Test $TEST_NAME completed successfully ==="
echo
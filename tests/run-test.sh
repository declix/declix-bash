#!/bin/bash
set -euxo pipefail

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
    bash -x setup.sh
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
echo "=== INITIAL STATE CHECK ==="
bash -x generated.sh check 2>&1 | tee initial_check.log
echo "=== END INITIAL STATE CHECK ==="

# Run apply to make changes
echo "=== APPLYING CHANGES ==="
bash -x generated.sh apply 2>&1 | tee apply.log
echo "=== END APPLYING CHANGES ==="

# Debug systemd state after apply
if [ "$TEST_NAME" = "systemd" ]; then
    echo "=== DEBUG: SYSTEMD STATE AFTER APPLY ==="
    echo "--- systemctl status ---"
    systemctl status --no-pager --all | grep -E "(test-|tmp-)" || true
    echo "--- systemctl list-units ---"
    systemctl list-units --all --no-pager | grep -E "(test-|tmp-)" || true
    echo "--- systemctl list-unit-files ---"
    systemctl list-unit-files --no-pager | grep -E "(test-|tmp-)" || true
    echo "--- journalctl for test services ---"
    journalctl -u test-app.service -u test-dependency.service -u test-complex.service --no-pager -n 50 || true
    echo "--- Check service processes ---"
    # shellcheck disable=SC2009
    ps aux | grep -E "(sleep|test-)" | grep -v grep || true
    echo "=== END DEBUG ==="
fi

# Run check again to verify final state
echo "=== FINAL STATE CHECK ==="
bash -x generated.sh check 2>&1 | tee final_check.log
echo "=== END FINAL STATE CHECK ==="

# Filter out bash debug lines for final_state.txt
grep -v "^+" final_check.log | grep -v "^++" > final_state.txt || true

# Run diff to verify no changes are needed after apply
echo "=== DIFF CHECK (should be empty) ==="
bash -x generated.sh diff 2>&1 | tee diff_check.log
echo "=== END DIFF CHECK ==="

# Filter out bash debug lines for diff output
grep -v "^+" diff_check.log | grep -v "^++" > diff_output.txt || true

# Check that diff output is empty (no changes needed)
if [ -s diff_output.txt ]; then
    echo "ERROR: Diff check shows pending changes after apply:"
    echo "=== DIFF OUTPUT ==="
    cat diff_output.txt
    echo "=== END DIFF OUTPUT ==="
    
    echo "=== COMPLETE APPLY LOG ==="
    cat apply.log
    echo "=== END APPLY LOG ==="
    
    echo "=== COMPLETE FINAL CHECK LOG ==="
    cat final_check.log
    echo "=== END FINAL CHECK LOG ==="
    
    exit 1
else
    echo "✓ Diff check passed - no pending changes after apply"
fi

# Run verify if exists to check resource statuses
if [ -f verify.sh ]; then
    echo "Verifying resource statuses..."
    chmod +x verify.sh
    bash -x verify.sh
else
    echo "No verify.sh found, checking that all resources show 'ok'..."
    echo "=== FINAL STATE CONTENT ==="
    cat final_state.txt
    echo "=== END FINAL STATE CONTENT ==="
    
    if grep -v "ok$" final_state.txt | grep -v "^$" | grep -v "^+" | grep -v "^++"; then
        echo "ERROR: Some resources are not in 'ok' state:"
        grep -v "ok$" final_state.txt | grep -v "^$" | grep -v "^+" | grep -v "^++"
        
        echo "=== COMPLETE APPLY LOG ==="
        cat apply.log
        echo "=== END APPLY LOG ==="
        
        echo "=== COMPLETE FINAL CHECK LOG ==="
        cat final_check.log
        echo "=== END FINAL CHECK LOG ==="
        
        echo "=== GENERATED SCRIPT ==="
        cat generated.sh
        echo "=== END GENERATED SCRIPT ==="
        
        exit 1
    fi
    echo "✓ All resources are in 'ok' state"
fi

echo "=== Test $TEST_NAME completed successfully ==="
echo
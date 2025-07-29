#!/bin/bash
set -euo pipefail

# Check final state file exists
if [ ! -f final_state.txt ]; then
    echo "ERROR: final_state.txt not found"
    exit 1
fi

# All users and groups should show "ok" after apply
expected_resources="user:testuser1 user:testsrv group:testgroup group:testsrv"

for resource in $expected_resources; do
    if ! grep -q "^$resource.*ok$" final_state.txt; then
        echo "ERROR: Resource $resource is not in 'ok' state"
        echo "Final state:"
        cat final_state.txt
        exit 1
    fi
done

# Verify actual system state for users
echo "Verifying testuser1..."
if ! id testuser1 >/dev/null 2>&1; then
    echo "ERROR: testuser1 should exist but doesn't"
    exit 1
fi

# Check testuser1 properties
user_info=$(getent passwd testuser1)
if ! echo "$user_info" | grep -q "testuser1:x:1500:1500:Test User One:/home/testuser1:/bin/bash"; then
    echo "ERROR: testuser1 properties don't match expected values"
    echo "Found: $user_info"
    exit 1
fi

echo "Verifying testsrv..."
if ! id testsrv >/dev/null 2>&1; then
    echo "ERROR: testsrv should exist but doesn't"
    exit 1
fi

# Check testsrv properties
user_info=$(getent passwd testsrv)
if ! echo "$user_info" | grep -q "testsrv:x:999:999:Test Service User:/var/lib/testsrv:/usr/sbin/nologin"; then
    echo "ERROR: testsrv properties don't match expected values"
    echo "Found: $user_info"
    exit 1
fi

# Verify groups
echo "Verifying testgroup..."
if ! getent group testgroup >/dev/null 2>&1; then
    echo "ERROR: testgroup should exist but doesn't"
    exit 1
fi

group_info=$(getent group testgroup)
if ! echo "$group_info" | grep -q "testgroup:x:1500:testuser1"; then
    echo "ERROR: testgroup properties don't match expected values"
    echo "Found: $group_info"
    exit 1
fi

echo "Verifying testsrv group..."
if ! getent group testsrv >/dev/null 2>&1; then
    echo "ERROR: testsrv group should exist but doesn't"
    exit 1
fi

group_info=$(getent group testsrv)
if ! echo "$group_info" | grep -q "testsrv:x:999:"; then
    echo "ERROR: testsrv group properties don't match expected values"
    echo "Found: $group_info"
    exit 1
fi

echo "✓ User test verified - all users and groups in correct state"
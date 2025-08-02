set fallback
# Install dependencies
deps:
    mise install

# Build declix-bash container image
build-container:
    podman build -f Containerfile -t declix-bash .

# Generate script using container
generate-in-container file: build-container
    podman run --rm -v {{justfile_directory()}}/{{file}}:/work/resources.pkl declix-bash /work/resources.pkl

# Generate script locally (requires pkl installed)
generate-local file:
    ./generate.sh {{file}}

# Run shellcheck on shell scripts
shellcheck:
    shellcheck generate.sh src/common.sh src/release-template.sh
    find . -name "*.sh" -not -path "./tests/*/generated.sh" -not -path "./local/*" -not -path "./node_modules/*" -not -path "./out/*" | xargs shellcheck

# Run all checks except container tests (for CI commits)
check-commit:
    @echo "=== Running commit checks ==="
    @echo ""
    @echo "1. Running shellcheck..."
    just shellcheck
    @echo "✓ Shellcheck passed"
    @echo ""
    @echo "2. Running Pkl tests..."
    pkl test tests/generate_test.pkl
    @echo "✓ Pkl tests passed"
    @echo ""
    @echo "3. Running generation tests..."
    just tests/test-local-generate
    @echo "✓ Generation tests passed"
    @echo ""
    @echo "4. Building release file..."
    just release
    @echo "✓ Release build passed"
    @echo ""
    @echo "5. Testing release file generation..."
    just tests/test-release-generate
    @echo "✓ Release generation tests passed"
    @echo ""
    @echo "=== All commit checks passed! ==="

# Run interactive container
run-in-container: build-container
    podman run --rm -it --entrypoint bash declix-bash

# Run tests (all in container)
test:
    just tests/test

# Clean up container images
clean:
    just tests/clean

# Create single-file release
release:
    #!/bin/bash
    set -euo pipefail
    
    # Create output directory
    mkdir -p out
    
    # Function to base64 encode a file
    encode_file() {
        base64 -w 0 < "$1"
    }
    
    # Read and encode the embedded files
    GENERATE_PKL_B64=$(encode_file "generate.pkl")
    COMMON_SH_B64=$(encode_file "src/common.sh")
    
    # Get version from git or default
    VERSION=$(git describe --tags --always 2>/dev/null || echo "dev")
    
    # Copy template to output
    cp src/release-template.sh out/declix-bash.sh
    
    # Replace placeholders
    sed -i "s/VERSION_PLACEHOLDER/$VERSION/g" out/declix-bash.sh
    sed -i "s/GENERATE_PKL_PLACEHOLDER/$GENERATE_PKL_B64/g" out/declix-bash.sh
    sed -i "s/COMMON_SH_PLACEHOLDER/$COMMON_SH_B64/g" out/declix-bash.sh
    
    # Make executable
    chmod +x out/declix-bash.sh
    
    echo "Created release: out/declix-bash.sh"
    echo "Size: $(du -h out/declix-bash.sh | cut -f1)"

# Test the released single-file script
test-release: release
    @echo "Testing release with empty.pkl..."
    ./out/declix-bash.sh examples/empty.pkl | head -20
    @echo ""
    @echo "Testing release with basic.pkl..."
    ./out/declix-bash.sh examples/basic.pkl | grep -E "(check|diff|apply)" | head -5
    @echo ""
    @echo "Testing help..."
    ./out/declix-bash.sh --help | head -10

# Test release file with all container tests
test-release-full: release
    just tests/test-release

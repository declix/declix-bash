set fallback
# Install dependencies
deps:
    mise install

# Build declix-bash container image
build:
    podman build -f Containerfile -t declix-bash .

# Generate script using container
generate file: build
    podman run --rm -v {{justfile_directory()}}/{{file}}:/work/resources.pkl declix-bash /work/resources.pkl

# Generate script locally (requires pkl installed)
generate-local file:
    ./generate.sh {{file}}

# Run shellcheck on shell scripts
shellcheck:
    shellcheck generate.sh src/common.sh
    find . -name "*.sh" -not -path "./tests/*/generated.sh" -not -path "./local/*" | xargs shellcheck

# Run interactive container
run: build
    podman run --rm -it --entrypoint bash declix-bash

# Run tests (all in container)
test:
    cd tests && just test

# Clean up container images
clean:
    cd tests && just clean

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
    
    # Create the single-file script
    cat > out/declix-bash.sh << 'EOF'
    #!/bin/bash
    # declix-bash - Declarative Linux configuration generator
    # Version: VERSION_PLACEHOLDER
    # This is a self-contained script with embedded resources
    
    set -euo pipefail
    
    # Show help if no arguments
    if [ $# -eq 0 ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
        cat << 'HELP'
    declix-bash - Generate idempotent Bash scripts from Pkl configurations
    
    Usage: declix-bash.sh <path_to_resources.pkl>
    
    The generated script supports three operations:
      check  - Check current system state
      diff   - Show differences between current and desired state  
      apply  - Apply the configuration
    
    Example:
      ./declix-bash.sh resources.pkl | bash -s check
      ./declix-bash.sh resources.pkl | bash -s diff
      ./declix-bash.sh resources.pkl | bash -s apply
    
    Requirements:
      - pkl (Apple's configuration language) must be installed
      - sudo access for system modifications
    
    Version: VERSION_PLACEHOLDER
    HELP
        exit 0
    fi
    
    # Embedded generate.pkl (base64 encoded)
    GENERATE_PKL_B64='GENERATE_PKL_PLACEHOLDER'
    
    # Embedded common.sh (base64 encoded)
    COMMON_SH_B64='COMMON_SH_PLACEHOLDER'
    
    # Create temporary directory for extraction
    TEMP_DIR=$(mktemp -d)
    trap 'rm -rf "$TEMP_DIR"' EXIT
    
    # Extract embedded files
    echo "$GENERATE_PKL_B64" | base64 -d > "$TEMP_DIR/generate.pkl"
    echo "$COMMON_SH_B64" | base64 -d > "$TEMP_DIR/common.sh"
    
    # Create a src directory for common.sh (expected by generate.pkl)
    mkdir -p "$TEMP_DIR/src"
    cp "$TEMP_DIR/common.sh" "$TEMP_DIR/src/common.sh"
    
    # Convert input to absolute path
    INPUT=$(realpath "$1")
    
    # Check if the input file is part of a PklProject
    INPUT_DIR=$(dirname "$INPUT")
    PROJECT_DIR=""
    
    # Walk up the directory tree to find PklProject
    CURRENT_DIR="$INPUT_DIR"
    while [ "$CURRENT_DIR" != "/" ]; do
        if [ -f "$CURRENT_DIR/PklProject" ]; then
            PROJECT_DIR="$CURRENT_DIR"
            break
        fi
        CURRENT_DIR=$(dirname "$CURRENT_DIR")
    done
    
    # Create temporary files for processing
    RESOURCES_FILE=$(mktemp).pkl
    OUTPUT_FILE=$(mktemp)
    
    # Cleanup on exit
    trap 'rm -f "$OUTPUT_FILE" "$RESOURCES_FILE" && rm -rf "$TEMP_DIR"' EXIT
    
    # Evaluate the input file, changing to project directory if needed
    if [ -n "$PROJECT_DIR" ]; then
        # Calculate relative path from project directory to input file
        RELATIVE_INPUT=$(realpath --relative-to="$PROJECT_DIR" "$INPUT")
        cd "$PROJECT_DIR"
        pkl eval "$RELATIVE_INPUT" > "$RESOURCES_FILE"
        cd - >/dev/null
    else
        pkl eval "$INPUT" > "$RESOURCES_FILE"
    fi
    
    # Create the Pkl evaluation file
    cat > "$OUTPUT_FILE" << PKL_EOF
    import "$TEMP_DIR/generate.pkl" as generate
    import "$RESOURCES_FILE" as input
    
    output {
        text = generate.generate(input.resources)
    }
    PKL_EOF
    
    # Run pkl and output the generated script
    pkl eval "$OUTPUT_FILE"
    EOF
    
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
    cd tests && just test-release

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
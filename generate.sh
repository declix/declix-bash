#!/bin/bash

set -eu
set -o pipefail

if [ -z "${1:-}" ] || [ "$1" = "--help" ] || [ "$1" = "-h" ]; then
    echo "Usage: $0 <path_to_resources.pkl>"
    echo ""
    echo "Generate idempotent Bash scripts from Pkl resource definitions."
    echo ""
    echo "Example:"
    echo "  $0 resources.pkl > deploy.sh"
    echo "  bash deploy.sh check"
    exit $([ "$1" = "--help" ] || [ "$1" = "-h" ] && echo 0 || echo 1)
fi

declix_bash_home=$(dirname "$(realpath "$0")")

# Convert input to absolute path
input=$(realpath "$1")

# First, evaluate the input file to get the resources without imports
resources_file=$(mktemp).pkl
output_file=$(mktemp)

# Set up cleanup trap
trap 'rm -f "$output_file" "$resources_file"' EXIT

# Check if the input file is part of a PklProject by looking for PklProject in its directory tree
input_dir=$(dirname "$input")
project_dir=""

# Walk up the directory tree to find PklProject
current_dir="$input_dir"
while [ "$current_dir" != "/" ]; do
    if [ -f "$current_dir/PklProject" ]; then
        project_dir="$current_dir"
        break
    fi
    current_dir=$(dirname "$current_dir")
done

# Evaluate the input file, changing to project directory if needed
if [ -n "$project_dir" ]; then
    # Calculate relative path from project directory to input file
    relative_input=$(realpath --relative-to="$project_dir" "$input")
    cd "$project_dir"
    pkl eval "$relative_input" > "$resources_file"
    cd - >/dev/null
else
    pkl eval "$input" > "$resources_file"
fi

# Create a temporary file with the preprocessed resources
cat <<EOF > "$output_file"
import "$declix_bash_home/generate.pkl" as generate
import "$resources_file" as input

output {
    text = generate.generate(input.resources)
}

EOF

pkl eval "$output_file"
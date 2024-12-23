#!/bin/bash
if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_resources.pkl>"
    exit 1
fi

declix_bash_home=$(dirname "$(realpath "$0")")

input="$1"
output_file=$(mktemp)

cat <<EOF > "$output_file"
import "$input" as input
import "$declix_bash_home/generate.pkl" as generate

output {
    text = generate.generate(input.resources)
}

EOF

pkl eval "$output_file"
rm "$output_file"
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
    find . -name "*.sh" -not -path "./tests/*/generated.sh" | xargs shellcheck

# Run interactive container
run: build
    podman run --rm -it --entrypoint bash declix-bash

# Run tests (all in container)
test:
    cd tests && just test

# Clean up container images
clean:
    cd tests && just clean

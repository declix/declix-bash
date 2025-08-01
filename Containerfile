FROM debian:12-slim

# Container metadata
LABEL org.opencontainers.image.title="declix-bash"
LABEL org.opencontainers.image.description="Bash script generator for declarative Linux system configuration using Pkl"
LABEL org.opencontainers.image.url="https://github.com/declix/declix-bash"
LABEL org.opencontainers.image.source="https://github.com/declix/declix-bash"
LABEL org.opencontainers.image.vendor="Declix"
LABEL org.opencontainers.image.licenses="MIT"

# Install only curl for downloading pkl
RUN apt-get update && apt-get install -y curl \
    && rm -rf /var/lib/apt/lists/*

# Download and install pkl manually (specific version for consistency)
ARG PKL_VERSION=0.27.1
RUN curl -L -o /usr/local/bin/pkl "https://github.com/apple/pkl/releases/download/${PKL_VERSION}/pkl-linux-amd64" \
    && chmod +x /usr/local/bin/pkl

WORKDIR /app

# Copy the pre-built single-file release
COPY out/declix-bash.sh /app/declix-bash.sh

# Make executable
RUN chmod +x /app/declix-bash.sh

# Entrypoint is the single-file release
ENTRYPOINT ["/app/declix-bash.sh"]
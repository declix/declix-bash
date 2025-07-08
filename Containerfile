FROM debian:12-slim

# Install required tools
RUN apt-get update && apt-get install -y \
    curl \
    git \
    shellcheck \
    && rm -rf /var/lib/apt/lists/*

# Install mise
RUN curl https://mise.run | sh && \
    echo 'eval "$(~/.local/bin/mise activate bash)"' >> ~/.bashrc

# Set up mise and install pkl
ENV PATH="/root/.local/bin:/root/.local/share/mise/shims:${PATH}"
RUN /root/.local/bin/mise install pkl@latest && \
    /root/.local/bin/mise use pkl@latest

# Copy project files
WORKDIR /app
COPY . /app

# Verify pkl is available
RUN pkl --version

# Entrypoint is generate.sh
ENTRYPOINT ["./generate.sh"]
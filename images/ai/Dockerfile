FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive \
    LANG=en_US.UTF-8 \
    LANGUAGE=en_US:en \
    LC_ALL=en_US.UTF-8

# Base packages
RUN apt-get update && apt-get install -y \
    curl wget git build-essential \
    ca-certificates gnupg unzip zip \
    sudo locales tzdata \
    bash-completion jq \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# Node.js 20 LTS
RUN curl -fsSL https://deb.nodesource.com/setup_20.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# ttyd — lightweight web terminal (mobile-friendly fallback)
ARG TTYD_VERSION=1.7.7
RUN curl -fsSL "https://github.com/tsl0922/ttyd/releases/download/${TTYD_VERSION}/ttyd.x86_64" \
    -o /usr/local/bin/ttyd \
    && chmod +x /usr/local/bin/ttyd

# Create coder user
# Ubuntu 24.04 ships with 'ubuntu' user at UID 1000 — remove it first
RUN userdel -r ubuntu 2>/dev/null || true \
    && useradd -m -s /bin/bash -u 1000 coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder

ENV PATH="/home/coder/.local/bin:/home/coder/.npm-global/bin:${PATH}"

USER coder

# Configure npm global prefix (persistent volume mount point)
RUN npm config set prefix /home/coder/.npm-global

# Install Claude Code via native installer
RUN curl -fsSL https://claude.ai/install.sh | bash

# Install Agent-OS from GitHub Packages using BuildKit secret (token not baked into image)
RUN --mount=type=secret,id=npm_token,uid=1000 \
    NPM_TOKEN=$(cat /run/secrets/npm_token) \
    && npm config set @elabx-org:registry https://npm.pkg.github.com \
    && npm config set //npm.pkg.github.com/:_authToken "$NPM_TOKEN" \
    && npm install -g @elabx-org/agent-os --legacy-peer-deps \
    && npm config delete //npm.pkg.github.com/:_authToken

WORKDIR /home/coder

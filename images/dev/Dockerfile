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
    bash-completion \
    && locale-gen en_US.UTF-8 \
    && rm -rf /var/lib/apt/lists/*

# JDK 21
RUN apt-get update && apt-get install -y openjdk-21-jdk \
    && rm -rf /var/lib/apt/lists/*

ENV JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64

# Kotlin
ARG KOTLIN_VERSION=2.1.20
RUN curl -fsSL https://github.com/JetBrains/kotlin/releases/download/v${KOTLIN_VERSION}/kotlin-compiler-${KOTLIN_VERSION}.zip \
    -o /tmp/kotlin.zip \
    && unzip -q /tmp/kotlin.zip -d /usr/local \
    && rm /tmp/kotlin.zip

# Go
ARG GO_VERSION=1.23.4
RUN curl -fsSL https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz \
    | tar -xz -C /usr/local

# Create coder user with passwordless sudo
RUN useradd -m -s /bin/bash -u 1000 coder \
    && echo "coder ALL=(ALL) NOPASSWD:ALL" > /etc/sudoers.d/coder \
    && chmod 0440 /etc/sudoers.d/coder

# Global PATH
ENV PATH="/usr/local/go/bin:/usr/local/kotlinc/bin:/home/coder/.local/bin:${PATH}"

# Install Claude Code as coder user
USER coder
RUN curl -fsSL https://claude.ai/install.sh | sh

WORKDIR /home/coder

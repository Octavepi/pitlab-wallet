# Use Ubuntu as base image
FROM ubuntu:22.04

# Prevent interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install essential build tools and dependencies
RUN apt-get update && apt-get install -y \
    build-essential \
    git \
    python3 \
    python3-pip \
    python3-venv \
    crossbuild-essential-arm64 \
    cmake \
    libssl-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
RUN useradd -ms /bin/bash vscode
USER vscode
WORKDIR /home/vscode

# Set up Python environment
ENV PATH="/home/vscode/.local/bin:${PATH}"

# Install Python dependencies
RUN python3 -m pip install --user --upgrade pip \
    && python3 -m pip install --user \
    click \
    protobuf \
    setuptools \
    wheel
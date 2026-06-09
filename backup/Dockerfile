FROM ghcr.io/astral-sh/uv:latest AS uv-installer
FROM python:3.12-slim

# Copy uv binary from official uv image
COPY --from=uv-installer /uv /usr/local/bin/uv

# Install Borg, PostgreSQL client tools, and SSH client
RUN apt-get update && apt-get install -y --no-install-recommends \
    borgbackup \
    openssh-client \
    postgresql-client \
    && rm -rf /var/lib/apt/lists/*

# Use uv to install borgmatic into system site-packages
RUN uv pip install --system borgmatic

# Set working directory for config
WORKDIR /backup

ENTRYPOINT []

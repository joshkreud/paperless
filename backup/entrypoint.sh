#!/bin/sh
set -euo pipefail

echo "Starting borgmatic backup service"

# Verify SSH keys are mounted (backup/.ssh -> /root/.ssh)
if [ -f /root/.ssh/id_ed25519 ] || [ -f /root/.ssh/id_rsa ]; then
  echo "SSH key found"
else
  echo "ERROR: No SSH key in backup/.ssh/ — run 'make backup-keygen' on the host"
  exit 1
fi

# Verify known_hosts is present (prevents MITM attacks)
if [ -f /root/.ssh/known_hosts ]; then
  echo "SSH known_hosts found"
else
  echo "ERROR: No known_hosts file in backup/.ssh/"
  echo "       Run 'make backup-known-hosts' on the host to generate it"
  exit 1
fi

# Verify pg_dump is available (required by borgmatic's postgresql_databases hook)
if ! command -v pg_dump >/dev/null 2>&1; then
  echo "ERROR: pg_dump not found — borgmatic cannot dump PostgreSQL without it"
  exit 1
fi

# Wait for Postgres to be reachable
echo "Waiting for PostgreSQL..."
until pg_isready -h "${PGHOST:-db}" -U "${PGUSER:-paperless}" >/dev/null 2>&1; do
  sleep 2
done
echo "PostgreSQL is ready"

# Initialize Borg repository if it doesn't exist yet (idempotent — skips if present)
borgmatic repo-create --encryption repokey --config /backup/config.yaml 2>/dev/null || true

# If arguments were passed (e.g. borgmatic ...), run them directly and exit
if [ $# -gt 0 ]; then
  exec "$@"
fi

# Otherwise, run borgmatic every 4 hours
while true; do
  echo "$(date): Starting borgmatic backup..."
  borgmatic --config /backup/config.yaml --verbosity 1 2>&1 || echo "$(date): borgmatic run failed"
  echo "$(date): Backup complete. Next run in 4h."
  sleep 14400
done

# Joshs Paperless Stack

Paperless-ngx with PostgreSQL, Redis, Paperless-AI, and automated Borg backups.

## Quick Start

```bash
make run                 # Start the stack and watch logs
make init-user           # Create initial superuser
make backup-keygen       # Generate SSH key for backups
make backup-known-hosts  # Fetch SSH host keys (from trusted network!)
make backup-run          # Run manual backup
make backup-list         # List all backups
make backup-restore      # Restore from latest backup
```

## Environment Variables

Create a `.env` file with:

```bash
BORG_REPO=ssh://user@host/path       # Borg repository URL
BORG_PASSPHRASE=...                  # Repo encryption passphrase
POSTGRES_PASSWORD=...                # Database password
TRAEFIK_HOST=paperless.example.com   # Web UI hostname
TRAEFIK_AI_HOST=ai.example.com       # AI UI hostname
COMPOSE_PROJECT_NAME=paperless       # Traefik label prefix
```

## SSH Setup (for remote Borg repos)

**One-time setup:**

```bash
make backup-keygen       # Generate SSH keypair in backup/.ssh/
                         # Add the printed public key to your Borg provider

make backup-known-hosts  # Fetch SSH host keys (run from trusted network!)
                         # Verify fingerprint matches provider docs
```

**Security note:** Backup will fail if `known_hosts` is missing (prevents MITM attacks).

## Backup

Automated daily encrypted Borg backups to `$BORG_REPO` (see [config.yaml](backup/config.yaml) for retention policy).

Backs up:

- `/media` and `/data` volumes
- PostgreSQL database (streamed, no extra disk space)

**Note:** `redisdata` is not backed up (transient task queue only).

```bash
make backup-run    # Manual backup
make backup-list   # List archives
```

## Restore

```bash
make backup-restore  # Restore DB + volumes from latest backup
make run             # Start the stack
```

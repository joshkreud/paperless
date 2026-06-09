# Joshs Paperless Stack

Paperless-ngx with PostgreSQL, Redis, and automated Borg backups.
Paperless-AI is available as an optional Compose override.

## Quick Start

```bash
make run                 # Start the stack and watch logs
make run-ai              # Start the stack with optional Paperless-AI
make init-user           # Create initial superuser
make backup-keygen       # Generate SSH key for backups
make backup-known-hosts  # Fetch SSH host keys (from trusted network!)
make backup-run          # Run manual backup
make backup-list         # List all backups
make backup-restore      # Restore from latest backup
make backup-export-key   # Export repokey (store securely!)
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

## Optional: Paperless-AI

Paperless-AI is not started by default. To enable it, include the override file:

```bash
docker compose -f docker-compose.yml -f docker-compose.paperless-ai.override.yml up -d
```

Or use:

```bash
make run-ai
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

## Disaster Recovery Checklist

Everything required to extract a backup on a fresh machine — store all of it somewhere durable and offline (e.g. a password manager vault + encrypted USB).

| #   | What                   | Where to find it             | Why it's needed                       |
| --- | ---------------------- | ---------------------------- | ------------------------------------- |
| 1   | **Borg repokey**       | `make backup-export-key`     | Decrypts the repository data          |
| 2   | **`BORG_PASSPHRASE`**  | `.env`                       | Unlocks the repokey                   |
| 3   | **`BORG_REPO` URL**    | `.env`                       | Locates the remote repository         |
| 4   | **SSH private key**    | `backup/.ssh/id_ed25519`     | Authenticates to the remote host      |
| 5   | **SSH public key**     | `backup/.ssh/id_ed25519.pub` | Re-register with provider if needed   |
| 6   | **`borgmatic` config** | `backup/config.yaml`         | Documents archive structure and paths |

### Exporting the repokey

Borg stores the repokey inside the repository itself. If the repo is lost or corrupted, you cannot decrypt your data without a separate copy of the key.

```bash
make backup-export-key   # Prints the repokey to stdout — copy and store it securely
```

### Restoring on a fresh machine

1. Install `borg` (`brew install borgbackup` / `apt install borgbackup`).
2. Copy `backup/.ssh/id_ed25519` to `~/.ssh/` and set permissions: `chmod 600 ~/.ssh/id_ed25519`.
3. Re-import the repokey if the repository was migrated:
   ```bash
   borg key import <BORG_REPO> -   # Paste the exported key, then Ctrl-D
   ```
4. List available archives to confirm access:
   ```bash
   BORG_PASSPHRASE=<passphrase> borg list <BORG_REPO>
   ```
5. Extract an archive:
   ```bash
   BORG_PASSPHRASE=<passphrase> borg extract <BORG_REPO>::<archive-name>
   ```
   Or use `make backup-restore` if the full stack is running.

# Load environment variables from .env file if it exists
-include .env
export

COMPOSE=docker compose
COMPOSE_AI=docker compose -f docker-compose.yml -f docker-compose.paperless-ai.override.yml

# Run the Stack and Watch Logs
run:
	$(COMPOSE) up -d --force-recreate --remove-orphans
	$(COMPOSE) logs -f

# Run the Stack with optional Paperless-AI override and watch logs
run-ai:
	$(COMPOSE_AI) up -d --force-recreate --remove-orphans
	$(COMPOSE_AI) logs -f

# On first Launch, initialize the user
init-user:
	docker compose run --rm webserver createsuperuser

# Generate a dedicated SSH keypair for the Borg backup container
backup-keygen:
	@mkdir -p backup/.ssh
	@if [ -f backup/.ssh/id_ed25519 ]; then \
		echo "Key already exists at backup/.ssh/id_ed25519"; \
	else \
		ssh-keygen -t ed25519 -N "" -C "paperless-backup" -f backup/.ssh/id_ed25519; \
		echo "Keypair generated."; \
	fi
	@echo ""
	@echo "=== Public key (add this to your Borg provider) ==="
	@cat backup/.ssh/id_ed25519.pub

# Generate SSH known_hosts file for the Borg repository
# This must be run from a trusted network to prevent MITM attacks
backup-known-hosts:
	@mkdir -p backup/.ssh
	@if [ -z "$(BORG_REPO)" ]; then \
		echo "ERROR: BORG_REPO not set. Source your .env file or set it manually:"; \
		echo "       make backup-known-hosts BORG_REPO=ssh://user@host/path"; \
		exit 1; \
	fi
	@REPO_HOST=$$(echo "$(BORG_REPO)" | sed -n 's|.*@\([^:/]*\).*|\1|p'); \
	if [ -z "$$REPO_HOST" ]; then \
		echo "ERROR: Could not extract hostname from BORG_REPO=$(BORG_REPO)"; \
		exit 1; \
	fi; \
	echo "Scanning SSH host keys from $$REPO_HOST..."; \
	ssh-keyscan -H "$$REPO_HOST" > backup/.ssh/known_hosts 2>/dev/null; \
	if [ -s backup/.ssh/known_hosts ]; then \
		echo "✓ Known hosts saved to backup/.ssh/known_hosts"; \
		echo "  Verify the fingerprint matches your provider's documentation!"; \
	else \
		echo "ERROR: Failed to retrieve host keys from $$REPO_HOST"; \
		rm -f backup/.ssh/known_hosts; \
		exit 1; \
	fi

# Run a one-shot borgmatic backup (does not start the scheduled loop)
backup-run:
	docker compose run --rm backup borgmatic --config /backup/config.yaml --verbosity 1

# Break a stale Borg lock (use after an interrupted backup)
backup-break-lock:
	docker compose run --rm backup borgmatic break-lock --config /backup/config.yaml

# Export the Borg repokey — store this somewhere safe to decrypt backups
backup-export-key:
	docker compose exec backup borg key export "$(BORG_REPO)" -


# List all backup archives
backup-list:
	docker compose run --rm backup borgmatic repo-list --config /backup/config.yaml

# Restore database and files from latest backup (WARNING: destructive)
backup-restore:
	@echo "WARNING: This will overwrite existing data!"
	@echo "Press Ctrl+C to cancel, or wait 5 seconds to continue..."
	@sleep 5
	docker compose up -d db
	docker compose run --rm backup borgmatic restore --archive latest --config /backup/config.yaml
	docker compose run --rm backup borgmatic extract --archive latest --destination / --config /backup/config.yaml

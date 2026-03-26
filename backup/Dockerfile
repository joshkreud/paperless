FROM librespace/borgmatic:latest

# Ensure PostgreSQL client tools and SSH client are available
RUN apk add --no-cache openssh-client \
    && (apk add --no-cache postgresql16-client 2>/dev/null \
    || apk add --no-cache postgresql-client 2>/dev/null \
    || true)

# Override base image entrypoint so it doesn't try to generate SSH keys
ENTRYPOINT []

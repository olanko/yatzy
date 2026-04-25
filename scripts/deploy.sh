#!/usr/bin/env bash
# Deploy yatzy-deploy.zip to the prod server, unpack, migrate, and
# restart the systemd-managed server.
#
# Reads scripts/.env for SSH target. Reads the server's
# $HOME/$REMOTE_DIR/.env for SECRET_KEY_BASE and DATABASE_PATH at
# deploy time.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

ENV_FILE="$SCRIPT_DIR/.env"
if [ ! -f "$ENV_FILE" ]; then
  echo "Missing $ENV_FILE — copy from .env.example and edit." >&2
  exit 1
fi

# shellcheck disable=SC1090
set -a
source "$ENV_FILE"
set +a

: "${SSH_USER:?SSH_USER not set in scripts/.env}"
: "${SSH_HOST:?SSH_HOST not set in scripts/.env}"
: "${REMOTE_DIR:?REMOTE_DIR not set in scripts/.env}"

ZIP="$PROJECT_ROOT/yatzy-deploy.zip"
TARGET="$SSH_USER@$SSH_HOST"

echo "→ Building $(basename "$ZIP")"
rm -f "$ZIP"
(
  cd "$PROJECT_ROOT"
  zip -rq "$ZIP" . \
    -x "_build/*" "deps/*" ".git/*" ".elixir_ls/*" \
       "yatzy_test.db*" "*.db-shm" "*.db-wal" \
       "yatzy-deploy.zip" "scripts/.env" \
       ".DS_Store" "**/.DS_Store"
)

REMOTE_RUNNER="$SCRIPT_DIR/remote_deploy.sh"
[ -f "$REMOTE_RUNNER" ] || { echo "$REMOTE_RUNNER not found" >&2; exit 1; }

echo "→ Copying $(basename "$ZIP") and remote_deploy.sh to $TARGET:~/$REMOTE_DIR/"
scp "$ZIP" "$REMOTE_RUNNER" "$TARGET:~/$REMOTE_DIR/"

echo "→ Deploying on $TARGET"
# Run the remote script as a real file (not piped via stdin) so mix
# tasks can't accidentally consume the rest of the script as input.
ssh "$TARGET" "bash ~/$REMOTE_DIR/remote_deploy.sh '$REMOTE_DIR'"

echo "✓ done"

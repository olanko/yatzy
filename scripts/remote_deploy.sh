#!/usr/bin/env bash
# Runs on the prod server. Invoked by scripts/deploy.sh after the zip
# has been copied to ~/$REMOTE_DIR/. Reads ~/$REMOTE_DIR/.env for
# SECRET_KEY_BASE and DATABASE_PATH.

set -euo pipefail

REMOTE_DIR="${1:?usage: remote_deploy.sh <remote_dir>}"

cd "$HOME/$REMOTE_DIR"

if [ -f .env ]; then
  echo "  loading $(pwd)/.env"
  set -a
  # shellcheck disable=SC1091
  source ./.env
  set +a
else
  echo "WARNING: $(pwd)/.env not found — SECRET_KEY_BASE / DATABASE_PATH may be missing"
fi

: "${SECRET_KEY_BASE:?SECRET_KEY_BASE not set on server (add to ~/$REMOTE_DIR/.env)}"
: "${DATABASE_PATH:?DATABASE_PATH not set on server (add to ~/$REMOTE_DIR/.env)}"

echo "  unzipping yatzy-deploy.zip"
unzip -oq yatzy-deploy.zip

echo "  fetching prod deps"
MIX_ENV=prod mix deps.get --only prod

echo "  cleaning stale digests"
MIX_ENV=prod mix phx.digest.clean --all

echo "  building assets"
MIX_ENV=prod mix assets.deploy

echo "  running migrations"
MIX_ENV=prod mix ecto.migrate

echo "  restarting yatzy.service"
sudo -n systemctl restart yatzy

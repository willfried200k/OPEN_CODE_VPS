#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "Usage: $0 <backup.tar.gz>" >&2
  exit 1
fi

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
ARCHIVE="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"

if [[ ! -f "$ARCHIVE" ]]; then
  echo "Archive not found: $ARCHIVE" >&2
  exit 1
fi

read -r -p "Overwrite container data with $ARCHIVE? [y/N] " answer
[[ "$answer" =~ ^[Yy]$ ]] || exit 1

docker compose -f "$COMPOSE_FILE" stop opencode >/dev/null 2>&1 || true

docker compose -f "$COMPOSE_FILE" run --rm --no-deps \
  -v "$ARCHIVE:/restore.tar.gz:ro" \
  --entrypoint sh opencode \
  -c "tar xzf /restore.tar.gz -C /"

echo "Restore complete. Start the stack with: docker compose -f $COMPOSE_FILE up -d"

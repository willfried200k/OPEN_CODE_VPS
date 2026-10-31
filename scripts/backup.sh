#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_DIR"

COMPOSE_FILE="${COMPOSE_FILE:-docker-compose.yml}"
BACKUP_DIR="${BACKUP_DIR:-$PROJECT_DIR/backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
BACKUP_FILE="$BACKUP_DIR/open_code_vps-$STAMP.tar.gz"

PATHS="root/.local root/.config"
if [[ "${WITH_WORKSPACE:-0}" == "1" ]]; then
  PATHS="$PATHS workspace"
fi

mkdir -p "$BACKUP_DIR"

echo "Archiving: $PATHS"
docker compose -f "$COMPOSE_FILE" run --rm --no-deps --entrypoint sh opencode \
  -c "tar czf - -C / $PATHS" > "$BACKUP_FILE"

echo "Backup written to $BACKUP_FILE"

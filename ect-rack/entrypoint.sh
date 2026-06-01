#!/bin/bash
set -e

DB_HOST=${DB_HOST:-db}
DB_PORT=${DB_PORT:-3306}
DB_NAME=${DB_NAME:-racktables}
DB_USER=${DB_USER:-racktables}
DB_PASS=${DB_PASS:-racktables_pass}

echo "[entrypoint] Waiting for database at ${DB_HOST}:${DB_PORT}..."
for i in $(seq 1 60); do
    if (echo > /dev/tcp/${DB_HOST}/${DB_PORT}) 2>/dev/null; then
        echo "[entrypoint] TCP port open, waiting 3s for MySQL to be ready..."
        sleep 3
        break
    fi
    echo "[entrypoint] Attempt ${i}/60, retrying in 2s..."
    sleep 2
done

echo "[entrypoint] Running auto-init..."
php /auto-init.php

echo "[entrypoint] Starting Apache..."
exec "$@"

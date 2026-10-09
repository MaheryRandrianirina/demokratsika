#!/bin/sh
set -e

# vendor/ et node_modules/ vivent dans des volumes nommés (isolés du bind mount).
# Un volume n'est peuplé depuis l'image qu'à sa création : sans cette synchro,
# un `--build` après un ajout de paquet garderait des dépendances périmées.
# Chaque service ne synchronise que ce dont il est responsable (SYNC_COMPOSER /
# SYNC_NPM) pour éviter deux installations concurrentes sur le même volume.

# $1 lockfile, $2 dossier de dépendances, $3... commande d'installation
sync_dependencies() {
    lockfile=$1
    directory=$2
    shift 2

    hash=$(md5sum "$lockfile" | cut -d' ' -f1)

    if [ "$(cat "$directory/.lock-hash" 2>/dev/null)" != "$hash" ]; then
        echo "$lockfile a changé : installation des dépendances…"
        "$@"
        echo "$hash" > "$directory/.lock-hash"
    fi
}

if [ "${SYNC_COMPOSER:-0}" = "1" ]; then
    sync_dependencies composer.lock vendor composer install --no-interaction --no-progress
fi

if [ "${SYNC_NPM:-0}" = "1" ]; then
    # `npm ci` et non `npm install` : ne réécrit jamais package-lock.json (bind mount).
    sync_dependencies package-lock.json node_modules npm ci --no-audit --no-fund
fi

exec "$@"

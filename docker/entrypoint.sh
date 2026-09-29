#!/bin/sh
set -e

# Caches config, events, routes and views with the real runtime environment,
# then hands over to the container command (Octane, migrate, queue:work…).
php artisan optimize --no-interaction

exec "$@"

FROM composer:2 AS composer-build
WORKDIR /app
COPY composer.json composer.lock ./
COPY app-modules ./app-modules
# --ignore-platform-reqs : ce stage ne fait que télécharger les paquets (aucune
# exécution). Les extensions réelles (pcntl, redis, intl…) sont fournies par le
# stage runtime FrankenPHP ci-dessous, donc la vérif de plateforme ici est inutile.
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --ignore-platform-reqs
COPY . .
RUN composer dump-autoload --optimize --no-dev

FROM dunglas/frankenphp:1-php8.4-alpine AS runtime
WORKDIR /app

RUN install-php-extensions pdo_mysql pcntl opcache zip redis intl

COPY --from=composer-build /app /app
COPY docker/frankenphp/Caddyfile /etc/caddy/Caddyfile
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

RUN chown -R www-data:www-data /app/storage /app/bootstrap/cache
USER www-data

ENV SERVER_NAME=":8080"
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8080/up || exit 1

# Caches config/routes at container start (real env is only present at
# runtime, not at build time) so `command:` overrides (migrate, queue:work)
# get the actual command instead of extra args appended to octane:frankenphp.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php", "artisan", "octane:frankenphp", "--host=0.0.0.0", "--port=8080", "--workers=4", "--max-requests=500"]
# Base commune : même PHP et mêmes extensions pour le build et le runtime, ce qui
# permet à Composer de vérifier la plateforme réelle (plus de --ignore-platform-reqs).
FROM dunglas/frankenphp:1-php8.4-alpine AS base
WORKDIR /app
RUN install-php-extensions pdo_pgsql pcntl opcache zip redis intl

FROM base AS composer-build
COPY --from=composer:2 /usr/bin/composer /usr/bin/composer
COPY composer.json composer.lock ./
COPY app-modules ./app-modules
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist --no-interaction
COPY . .
RUN composer dump-autoload --optimize --no-dev \
    # Pré-installe le worker Octane : au runtime, public/ n'est pas modifiable par www-data.
    && cp vendor/laravel/octane/src/Commands/stubs/frankenphp-worker.php public/frankenphp-worker.php \
    && php artisan storage:link

# Le plugin Vite Wayfinder lance `php artisan wayfinder:generate` pendant le build :
# ce stage a donc besoin de PHP en plus de Node.
FROM base AS frontend-build
RUN apk add --no-cache nodejs npm
COPY package.json package-lock.json .npmrc ./
RUN npm ci --no-audit --no-fund
COPY --from=composer-build /app /app
RUN npm run build

FROM base AS runtime

RUN cp "$PHP_INI_DIR/php.ini-production" "$PHP_INI_DIR/php.ini"
COPY docker/php/production.ini "$PHP_INI_DIR/conf.d/zz-production.ini"

COPY --from=composer-build /app /app
COPY --from=frontend-build /app/public/build /app/public/build
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh

# Le code reste propriété de root (lecture seule pour l'app) ; seuls storage/,
# bootstrap/cache et les dossiers Caddy (XDG_DATA_HOME / XDG_CONFIG_HOME) sont inscriptibles.
RUN chmod +x /usr/local/bin/entrypoint.sh \
    && chown -R www-data:www-data /app/storage /app/bootstrap/cache /data/caddy /config/caddy

USER www-data

ENV SERVER_NAME=":8080" \
    LOG_CHANNEL=stderr
EXPOSE 8080

HEALTHCHECK --interval=30s --timeout=5s --retries=3 \
    CMD curl -f http://localhost:8080/up || exit 1

# Caches config/routes at container start (real env is only present at
# runtime, not at build time) so `command:` overrides (migrate, queue:work)
# get the actual command instead of extra args appended to octane:frankenphp.
# Workers : `auto` (1 par CPU) par défaut, surchargeable via `command: ... --workers=N`.
ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
CMD ["php", "artisan", "octane:frankenphp", "--host=0.0.0.0", "--port=8080", "--max-requests=500"]

# Demokratsika

[![CI](https://github.com/MaheryRandrianirina/demokratsika/actions/workflows/ci.yml/badge.svg)](https://github.com/MaheryRandrianirina/demokratsika/actions/workflows/ci.yml)

Application Laravel 13 + Inertia (React), servie par Laravel Octane sur FrankenPHP.

| Couche           | Stack                                                                 |
| ---------------- | --------------------------------------------------------------------- |
| Backend          | PHP 8.4, Laravel 13, Fortify (auth), Wayfinder, internachi/modular    |
| Frontend         | Inertia v3, React 19, TypeScript, Tailwind CSS v4, Vite 8 (vite-plus) |
| Runtime          | Laravel Octane sur FrankenPHP                                         |
| Données & queues | PostgreSQL 18, Redis 7, Laravel Horizon                               |
| Qualité          | Pest 5, PHPStan (Larastan), Pint                                      |

## Prérequis

L'environnement de développement tourne entièrement dans Docker : inutile d'installer PHP, Composer ou Node sur votre machine.

- [Docker Desktop](https://www.docker.com/products/docker-desktop/) (ou Docker Engine avec le plugin Compose)
- Git

> **Windows :** Horizon nécessite l'extension `pcntl`, qui n'existe pas sous Windows. Utilisez Docker plutôt qu'une installation PHP native.

## Démarrage rapide

```bash
git clone git@github.com:MaheryRandrianirina/demokratsika.git
cd demokratsika

# 1. Créer le fichier d'environnement (il cible déjà les services Docker)
cp .env.example .env

# 2. Construire l'image et générer la clé de l'application
docker compose build
docker compose run --rm --no-deps app php artisan key:generate

# 3. Démarrer la stack
docker compose up -d

# 4. Créer le schéma de la base de données
docker compose exec app php artisan migrate
```

Le premier build prend quelques minutes (les dépendances Composer et npm sont installées dans l'image). Ouvrez **http://localhost:8080** dès que `docker compose ps` affiche `app` en `healthy`.

## Services

| Service     | URL / accès                       | Rôle                                                  |
| ----------- | --------------------------------- | ----------------------------------------------------- |
| `app`       | http://localhost:8080             | Octane + FrankenPHP, rechargé à chaque modif PHP      |
| `vite`      | http://localhost:5173             | Serveur de dev Vite (hot module replacement)          |
| `worker`    | http://localhost:8080/horizon     | Workers de queue Horizon + tableau de bord            |
| `scheduler` | —                                 | Exécute `schedule:work` (tâches planifiées)           |
| `pg`        | interne uniquement (`pg:5432`)    | PostgreSQL 18                                         |
| `redis`     | interne uniquement (`redis:6379`) | Cache, sessions et queues                             |
| `adminer`   | http://127.0.0.1:8082             | Interface d'admin BDD (accessible en local seulement) |

**Connexion Adminer :** système `PostgreSQL`, serveur `pg`, utilisateur `postgres`, mot de passe `secret`, base `demokratsika-db` (valeurs issues de `.env`).

## Commandes courantes

Lancez Artisan, Composer et npm **dans les conteneurs** : `.env` pointe vers les hôtes `pg` et `redis`, qui ne sont résolus que sur le réseau Docker.

```bash
docker compose up -d                  # démarrer la stack
docker compose down                   # l'arrêter (les données sont conservées)
docker compose logs -f app worker     # suivre les logs
docker compose ps                     # état des services

docker compose exec app php artisan <commande>     # Artisan
docker compose exec app php artisan tinker
docker compose exec app composer <commande>        # Composer
docker compose exec vite npm <commande>            # npm
```

### Ajouter des dépendances

```bash
docker compose exec app composer require vendor/package
docker compose exec vite npm install nom-du-paquet
```

`vendor/` et `node_modules/` vivent dans des volumes Docker, pas sur votre machine. Quand `composer.lock` ou `package-lock.json` change (par exemple après un `git pull`), les conteneurs réinstallent automatiquement les dépendances à leur prochain démarrage : `docker compose up -d --build`.

## Tests et qualité du code

```bash
docker compose exec app php artisan test             # suite de tests Pest
docker compose exec app vendor/bin/pint              # corriger le style PHP
docker compose exec app vendor/bin/phpstan analyse   # analyse statique

docker compose exec vite npm run check               # lint + vérification du formatage (vp check)
docker compose exec vite npm run check:fix           # correction automatique
docker compose exec vite npm run types:check         # TypeScript
```

Les tests utilisent une base SQLite en mémoire (voir `phpunit.xml`) : ils ne touchent jamais à vos données de développement.

## Déboguer avec Xdebug

Xdebug est installé mais désactivé par défaut, car il ralentit nettement Octane et Horizon. Pour l'activer :

```bash
XDEBUG_MODE=debug docker compose up -d app
```

Xdebug démarre sur déclencheur (par exemple l'extension navigateur _Xdebug helper_, ou `XDEBUG_TRIGGER=1`) et se connecte à votre IDE sur `host.docker.internal:9003`. Dans l'IDE, mappez la racine du projet sur `/app`. Relancez `docker compose up -d app` pour le désactiver.

## Structure du projet

```
app/                             Code de l'application Laravel
app-modules/                     Modules métier (internachi/modular) : src/, routes/, database/, tests/
resources/js/                    Pages Inertia et composants React
resources/js/actions, routes/    TypeScript généré par Wayfinder (ignoré par git, généré par Vite)
docker/                          Entrypoints des conteneurs et configuration PHP
.github/                         Workflows CI, Dependabot et actions partagées
```

Créer un nouveau module : `docker compose exec app php artisan make:module <nom>`.

## Dépannage

| Symptôme                                           | Solution                                                                                                                   |
| -------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------- |
| `Class "…" not found` après un `git pull`          | `docker compose up -d --build` (les dépendances se resynchronisent au démarrage)                                           |
| Page sans styles / erreurs Vite                    | Vérifiez `docker compose logs vite` : le service `vite` doit tourner                                                       |
| `database "…" does not exist`                      | Postgres ne lit `DB_DATABASE` qu'au tout premier démarrage. Créez-la : `docker compose exec pg createdb -U postgres <nom>` |
| Repartir de zéro (**supprime toutes les données**) | `docker compose down -v && docker compose up -d --build`, puis relancez les migrations                                     |
| Port 8080, 5173 ou 8082 déjà utilisé               | Arrêtez l'autre processus, ou changez le port hôte dans `docker-compose.yml`                                               |

## Production

`docker-compose.prod.yml` lance l'image de production (`Dockerfile`) : une image immuable, sans bind mount ni outils de dev. Elle tourne avec un utilisateur non-root, OPcache optimisé et logs envoyés sur stderr.

```bash
# .env doit contenir les valeurs de production (APP_KEY, DB_*, REDIS_*…)
docker compose -f docker-compose.prod.yml up -d --build
```

- Un service ponctuel `migrate` exécute `migrate --force` ; `app`, `worker` et `scheduler` ne démarrent qu'une fois les migrations réussies.
- Les fichiers uploadés sont stockés dans le volume `storage`.
- Pour déployer une image construite par la CI au lieu de builder localement, définissez `APP_IMAGE`, par exemple `APP_IMAGE=ghcr.io/maheryrandrianirina/demokratsika:sha-abc1234`.

## Intégration continue

Les workflows GitHub Actions se trouvent dans `.github/workflows/` :

| Workflow       | Contenu                                                                                     |
| -------------- | ------------------------------------------------------------------------------------------- |
| `ci.yml`       | Pint, PHPStan, lint/types/build du frontend, tests sur PHP 8.4 et 8.5 (SQLite) + PostgreSQL |
| `docker.yml`   | Build de l'image de production ; push sur GHCR depuis `main` et les tags `v*`               |
| `security.yml` | Revue des dépendances, `composer audit`, `npm audit`, analyse des workflows (zizmor)        |
| `codeql.yml`   | Analyse CodeQL du TypeScript et des workflows                                               |

Marquez le check **`CI success`** comme requis dans les règles de protection de la branche `main`. Dependabot ouvre chaque semaine des PR de mise à jour pour Composer, npm, les images Docker et les GitHub Actions.

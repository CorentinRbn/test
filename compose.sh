#!/usr/bin/env bash
set -euo pipefail

# ============================================
# Script helper pour docker compose (commenté)
# ============================================
# Objectif: simplifier l'usage avec des commandes courtes :
#   ./compose.sh up       -> build + up -d
#   ./compose.sh stop     -> stop les services
#   ./compose.sh down [-v]-> supprime les conteneurs (et -v supprime les volumes)
#   ./compose.sh logs     -> affiche les logs en continu
#   ./compose.sh restart  -> restart
#   ./compose.sh sh <svc> -> ouvre un shell dans un service (web|db)
#
# Le script copie automatiquement .env.example vers .env s'il n'existe pas.

if [[ ! -f ".env" ]]; then
  echo "[i] Aucun .env trouvé, copie de .env.example -> .env"
  cp .env.example .env
  echo "[i] Pensez à éditer .env si besoin (mots de passe, port, etc.)."
fi

cmd="${1:-help}"

case "$cmd" in
  up)
    # Construit les images perso (Dockerfiles) puis démarre en détaché
    docker compose build
    docker compose up -d
    echo "[✓] Démarré. Ouvrez http://localhost:${WEB_PORT:-8080}"
    ;;
  stop)
    docker compose stop
    ;;
  down)
    # Avec -v on supprime AUSSI les volumes (=> reset base de données)
    shift || true
    docker compose down "$@"
    ;;
  logs)
    docker compose logs -f --tail=200
    ;;
  restart)
    docker compose restart
    ;;
  sh)
    # Ouvre un shell dans 'web' (par défaut) ou dans le service passé en arg.
    svc="${2:-web}"
    docker compose exec "$svc" bash || docker compose exec "$svc" sh
    ;;
  *)
    cat <<'USAGE'
Usage: ./compose.sh <commande> [options]

Commandes:
  up            Build + up -d
  stop          Stoppe les services
  down [-v]     Supprime les conteneurs (et -v supprime les volumes)
  logs          Montre les logs en continu
  restart       Redémarre les services
  sh [svc]      Ouvre un shell dans le conteneur (web|db)

Exemples:
  ./compose.sh up
  ./compose.sh down -v
  ./compose.sh sh web
USAGE
    ;;
esac

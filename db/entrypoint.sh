#!/usr/bin/env bash
set -euo pipefail

DATADIR="/var/lib/mysql"

# Créer le répertoire pour le socket MySQL
mkdir -p /run/mysqld
chown mysql:mysql /run/mysqld

# Variables d'environnement
ROOT_PW="${MYSQL_ROOT_PASSWORD:-root}"
DB_NAME="${DB_NAME:-dvwa}"
DB_USER="${DB_USER:-dvwa}"
DB_PASSWORD="${DB_PASSWORD:-user}"

# Si le répertoire data est vide, initialiser la base
if [ ! -d "$DATADIR/mysql" ]; then
  echo "[db] Initialisation du datadir..."
  install -d -o mysql -g mysql "$DATADIR"
  chown -R mysql:mysql /var/lib/mysql
  mysql_install_db --user=mysql --datadir="$DATADIR"
  echo "[db] Datadir initialisé."
  
  # Démarrer temporairement SANS skip-networking pour permettre les connexions TCP
  echo "[db] Démarrage temporaire pour configuration..."
  mysqld --user=mysql --bind-address=127.0.0.1 --port=3306 &
  pid="$!"
  
  # Attendre que le serveur soit prêt
  for i in {30..0}; do
    if mysqladmin ping -h127.0.0.1 &>/dev/null; then
      break
    fi
    echo "[db] Attente du démarrage de MariaDB... ($i)"
    sleep 1
  done
  
  if ! mysqladmin ping -h127.0.0.1 &>/dev/null; then
    echo >&2 "[db] Échec du démarrage initial de MariaDB."
    exit 1
  fi
  
  # Configuration initiale (pas de mot de passe car DB fraîche)
  echo "[db] Configuration de la base de données..."
  mysql -h127.0.0.1 <<SQL
-- Sécuriser l'utilisateur root
ALTER USER 'root'@'localhost' IDENTIFIED BY '${ROOT_PW}';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;

-- Créer la base DVWA
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;

-- Créer l'utilisateur applicatif
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
FLUSH PRIVILEGES;
SQL
  
  # Arrêter le serveur temporaire
  echo "[db] Arrêt du serveur temporaire..."
  mysqladmin -h127.0.0.1 -uroot -p"${ROOT_PW}" shutdown
  wait "$pid" || true
  
  echo "[db] Configuration initiale terminée."
fi

echo "[db] Lancement de MariaDB en mode production..."

# Démarrer MySQL avec écoute réseau sur toutes les interfaces
exec mysqld --user=mysql --bind-address=0.0.0.0 --port=3306

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

# Fonction utilitaire pour lancer un serveur MySQL temporaire et exécuter un script SQL
run_mysql_once() {
  local auth=(-uroot)
  local admin_auth=(-uroot)
  if [ "${1:-}" = "--password" ]; then
    auth=(-uroot "-p$2")
    admin_auth=(-uroot "-p$2")
    shift 2
  fi

  local sql_input
  sql_input="$(cat)"

  mysqld \
    --user=mysql \
    --skip-networking \
    --datadir="$DATADIR" \
    --socket=/run/mysqld/mysqld.sock \
    --pid-file=/run/mysqld/ensure.pid \
    --log-error=/var/lib/mysql/bootstrap.log &
  local pid="$!"

  for i in {30..0}; do
    if mysqladmin "${admin_auth[@]}" --socket=/run/mysqld/mysqld.sock ping &>/dev/null; then
      break
    fi
    echo "[db] Attente du démarrage de MariaDB... ($i)"
    sleep 1
  done

  if ! mysqladmin "${admin_auth[@]}" --socket=/run/mysqld/mysqld.sock ping &>/dev/null; then
    echo >&2 "[db] Échec du démarrage temporaire de MariaDB."
    exit 1
  fi

  mysql --socket=/run/mysqld/mysqld.sock "${auth[@]}" <<SQL
${sql_input}
SQL

  if ! mysqladmin "${admin_auth[@]}" --socket=/run/mysqld/mysqld.sock --force shutdown >/dev/null 2>&1; then
    mysqladmin -uroot "-p${ROOT_PW}" --socket=/run/mysqld/mysqld.sock --force shutdown >/dev/null 2>&1 || true
  fi
  wait "$pid" || true
}

configured_fresh=0

# Si le répertoire data est vide, initialiser la base
if [ ! -d "$DATADIR/mysql" ]; then
  echo "[db] Initialisation du datadir..."
  install -d -o mysql -g mysql "$DATADIR"
  chown -R mysql:mysql /var/lib/mysql
  mysql_install_db --user=mysql --datadir="$DATADIR"
  echo "[db] Datadir initialisé."
  
  configured_fresh=1

  # Configuration initiale (pas de mot de passe car DB fraîche)
  echo "[db] Configuration de la base de données..."
  run_mysql_once <<SQL
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
CREATE USER IF NOT EXISTS '${DB_USER}'@'dvwa_web' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'dvwa_web.tp2_dvwa_net' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'dvwa_web';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'dvwa_web.tp2_dvwa_net';
FLUSH PRIVILEGES;
SQL
fi

if [ "$configured_fresh" -eq 0 ]; then
  echo "[db] Vérification des comptes applicatifs existants..."
  run_mysql_once --password "${ROOT_PW}" <<SQL
-- Garantir la présence de la base et des utilisateurs DVWA
CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
CREATE USER IF NOT EXISTS '${DB_USER}'@'%' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'dvwa_web' IDENTIFIED BY '${DB_PASSWORD}';
CREATE USER IF NOT EXISTS '${DB_USER}'@'dvwa_web.tp2_dvwa_net' IDENTIFIED BY '${DB_PASSWORD}';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'%';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'dvwa_web';
GRANT ALL PRIVILEGES ON \`${DB_NAME}\`.* TO '${DB_USER}'@'dvwa_web.tp2_dvwa_net';
FLUSH PRIVILEGES;
SQL
fi

echo "[db] Lancement de MariaDB en mode production..."

# Démarrer MySQL avec écoute réseau sur toutes les interfaces
exec mysqld --user=mysql --bind-address=0.0.0.0 --port=3306

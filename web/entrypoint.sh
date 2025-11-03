#!/usr/bin/env bash
set -euo pipefail

: "${DB_HOST:?DB_HOST doit être défini}"
: "${DB_NAME:?DB_NAME doit être défini}"
: "${DB_USER:?DB_USER doit être défini}"
: "${DB_PASSWORD:?DB_PASSWORD doit être défini}"
: "${DVWA_SECURITY:=low}"

DVWA_ROOT="/var/www/html/dvwa"
CONFIG_FILE="$DVWA_ROOT/config/config.inc.php"

echo "[web] Configuration de DVWA..."

# Générer config.inc.php depuis le template si nécessaire
if [ ! -f "$CONFIG_FILE" ]; then
  echo "[web] Création du fichier de configuration..."

  # Copier le template
  cp "$DVWA_ROOT/config/config.inc.php.dist" "$CONFIG_FILE"

  # Remplacer les valeurs par les variables d'environnement
  sed -i "s/\$_DVWA\[ 'db_server' \].*=.*/\$_DVWA[ 'db_server' ]   = '${DB_HOST}';/" "$CONFIG_FILE"
  sed -i "s/\$_DVWA\[ 'db_database' \].*=.*/\$_DVWA[ 'db_database' ] = '${DB_NAME}';/" "$CONFIG_FILE"
  sed -i "s/\$_DVWA\[ 'db_user' \].*=.*/\$_DVWA[ 'db_user' ]     = '${DB_USER}';/" "$CONFIG_FILE"
  sed -i "s/\$_DVWA\[ 'db_password' \].*=.*/\$_DVWA[ 'db_password' ] = '${DB_PASSWORD}';/" "$CONFIG_FILE"

  # Définir le niveau de sécurité
  sed -i "s/\$_DVWA\[ 'default_security_level' \].*=.*/\$_DVWA[ 'default_security_level' ] = '${DVWA_SECURITY}';/" "$CONFIG_FILE"

  # Autoriser la création automatique de la DB
  sed -i "s/\$_DVWA\[ 'recaptcha_public_key' \].*=.*/\$_DVWA[ 'recaptcha_public_key' ]  = '';/" "$CONFIG_FILE"
  sed -i "s/\$_DVWA\[ 'recaptcha_private_key' \].*=.*/\$_DVWA[ 'recaptcha_private_key' ] = '';/" "$CONFIG_FILE"

  chown www-data:www-data "$CONFIG_FILE"
  echo "[web] Configuration créée."
fi

# S'assurer que les permissions sont correctes
chown -R www-data:www-data "$DVWA_ROOT"

# S'assurer que les dossiers uploadables sont accessibles en écriture
chmod -R 775 "$DVWA_ROOT/hackable/uploads" "$DVWA_ROOT/external/phpids/0.6/lib/IDS/tmp" || true

echo "[web] Démarrage d'Apache..."
exec "$@"

# Image MariaDB basée sur Debian (pas d'alpine) — Dockerfile personnel
FROM debian:bookworm-slim

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y --no-install-recommends \
      mariadb-server \
      tini \
    && rm -rf /var/lib/apt/lists/*

# Config my.cnf additionnelle
COPY 50-server.cnf /etc/mysql/mariadb.conf.d/50-server.cnf

# Entrypoint custom: initialise la DB à partir des variables d'env si nécessaire
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

EXPOSE 3306

ENV MYSQL_ROOT_PASSWORD=root \
    DB_NAME=dvwa \
    DB_USER=dvwa \
    DB_PASSWORD=user

VOLUME ["/var/lib/mysql"]

ENTRYPOINT ["/usr/bin/tini","--","/entrypoint.sh"]
CMD ["mysqld"]

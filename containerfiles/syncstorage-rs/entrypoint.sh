#!/bin/bash

# First run all migrations
/app/bin/diesel --database-url "${SYNC_SYNCSTORAGE_DATABASE_URL}" migration --migration-dir /app/migrations/syncstorage-mysql run
/app/bin/diesel --database-url "${SYNC_TOKENSERVER_DATABASE_URL}" migration --migration-dir /app/migrations/tokenserver-db run

# Parse token server database URL
proto="$(echo "$SYNC_TOKENSERVER_DATABASE_URL" | grep :// | sed -e's,^\(.*://\).*,\1,g')"
url="${SYNC_TOKENSERVER_DATABASE_URL/$proto/}"
userpass="$(echo "$url" | grep @ | cut -d@ -f1)"
pass="$(echo "$userpass" | grep : | cut -d: -f2)"
user="$(echo "$userpass" | grep : | cut -d: -f1)"
host="$(echo "${url/$user:$pass@/}" | cut -d/ -f1)"
port="$(echo "$host" | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"
host="$(echo "${host/:$port/}" | cut -d/ -f1)"
db="$(echo "$url" | grep / | cut -d/ -f2-)"

# Create service and node if they doesnt exist
mariadb "$db" -h "$host" -P "$port" -u "$user" -p"$pass" <<EOF
DELETE FROM services;
INSERT INTO services (id, service, pattern) VALUES
    (1, "sync-1.5", "{node}/1.5/{uid}");
INSERT INTO nodes (id, service, node, capacity, available, current_load, downed, backoff) VALUES
    (1, 1, "${SYNC_URL}", ${SYNC_CAPACITY}, ${SYNC_CAPACITY}, 0, 0, 0)
    ON DUPLICATE KEY UPDATE node = "${SYNC_URL}", capacity = ${SYNC_CAPACITY}, available = (SELECT ${SYNC_CAPACITY} - current_load from (SELECT * FROM nodes) as n2 where id = 1);
EOF

# Write config file
cat << EOF > /config/local.toml
master_secret = "${SYNC_MASTER_SECRET}"

human_logs = 1

host = "0.0.0.0"
port = 8000

syncstorage.database_url = "${SYNC_SYNCSTORAGE_DATABASE_URL}"
syncstorage.enable_quota = 0
syncstorage.enabled = true

tokenserver.database_url = "${SYNC_TOKENSERVER_DATABASE_URL}"
tokenserver.enabled = true
tokenserver.fxa_email_domain = "api.accounts.firefox.com"
tokenserver.fxa_metrics_hash_secret = "${METRICS_HASH_SECRET}"
tokenserver.fxa_oauth_server_url = "https://oauth.accounts.firefox.com"
tokenserver.fxa_browserid_audience = "https://token.services.mozilla.com"
tokenserver.fxa_browserid_issuer = "https://api.accounts.firefox.com"
tokenserver.fxa_browserid_server_url = "https://verifier.accounts.firefox.com/v2"
EOF

if [ -z "$LOGLEVEL" ]; then
  LOGLEVEL=warn
fi

RUST_LOG=$LOGLEVEL /app/bin/syncserver --config /config/local.toml

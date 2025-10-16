#!/bin/sh

cat "/rclone.conf.in" | \
  sed "s/@ACCESS_KEY_ID@/${ACCESS_KEY_ID}/g" | \
  sed "s/@SECRET_ACCESS_KEY@/${SECRET_ACCESS_KEY}/g" | \
  sed "s/@REGION_ENDPOINT@/${REGION_ENDPOINT}/g" > "/tmp/rclone.conf"

while true; do
  sleep 300 &
  rclone sync \
    --config /tmp/rclone.conf \
    --delete-after \
    --track-renames \
    --delete-excluded \
    --fast-list \
    --transfers "${TRANSFERS}" \
    --stats 5s \
    --stats-one-line \
    --verbose \
    --http-url "${HTTP_URL}" \
    :http: \
    "storage:${BUCKET_NAME}/${DESTINATION_ROOT}"
  size="$(rclone --config /tmp/rclone.conf size "storage:${BUCKET_NAME}/${DESTINATION_ROOT}" | sed 's/$/\\n/g' | tr -d '\n')"
  ts="$(date -u -Iseconds)"
  cat "/stats.html.in" | \
    sed "s|@SIZE_OUTPUT@|${size}|g" | \
    sed "s|@LAST_SYNCED_TIMESTAMP@|${ts}|g" > /tmp/index.html
  rclone --config /tmp/rclone.conf copy /tmp/index.html "storage:${STATS_BUCKET_NAME}/${DESTINATION_ROOT}"
  wait
done

#!/bin/sh

CONTAINER_ID="$(docker ps | grep mongo | awk '{print $1}')"
echo "$CONTAINER_ID"

if [ -z "$CONTAINER_ID" ]; then
  echo "Failed to get container ID. Exiting."
  exit
fi

MONGODUMP_FILE="$1"

if [ -z "$MONGODUMP_FILE" ]; then
  echo "Specify mongodump file on command line. Exiting."
  exit
fi

if [ ! -f "$MONGODUMP_FILE" ]; then
  echo "File '$MONGODUMP_FILE' does not exist"
  exit
fi

docker exec -i "$CONTAINER_ID" sh -c "mongo mongo --eval \"db.dropDatabase()\""
docker exec -i "$CONTAINER_ID" sh -c "mongorestore --gzip --archive" < "$MONGODUMP_FILE"
docker exec -i "$CONTAINER_ID" sh -c "mongodump -d mongo -o=/data/mongodump/"
docker exec -i "$CONTAINER_ID" sh -c "mongo treestats-dev --eval \"db.dropDatabase()\""
docker exec -i "$CONTAINER_ID" sh -c "mongorestore -d treestats-dev /data/mongodump/mongo"
docker exec "$CONTAINER_ID" sh -c 'mongo mongo --eval "db.dropDatabase()"'

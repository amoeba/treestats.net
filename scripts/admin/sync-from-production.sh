#!/bin/sh

HOST=$1
EXPORT_FILE="mongo-export"

print_usage() {
  echo "\nUSAGE\n"
  echo "./sync-from-production.sh HOST"
}

if [ -z "$HOST" ]; then
  echo "No host specified. Exiting."
  print_usage
  exit
fi

echo "Connecting to $HOST and running mongo_dump..."
ssh "$1" dokku mongo:export mongo > mongo-export
echo "Done."

if [ ! -f "$EXPORT_FILE" ]; then
  echo "File $EXPORT_FILE not found. Previous step must have failed."
  exit
fi

CONTAINER_ID="$(docker ps | grep mongo | awk '{print $1}')"
echo "Found MongoDB container: $CONTAINER_ID"

if [ -z "$CONTAINER_ID" ]; then
  echo "Failed to get container ID. Exiting."
  exit
fi

docker exec -i "$CONTAINER_ID" sh -c "mongo mongo --eval \"db.dropDatabase()\""
docker exec -i "$CONTAINER_ID" sh -c "mongorestore --gzip --archive" < "$EXPORT_FILE"
docker exec -i "$CONTAINER_ID" sh -c "mongodump -d mongo -o=/data/mongodump/"
docker exec -i "$CONTAINER_ID" sh -c "mongo treestats-dev --eval \"db.dropDatabase()\""
docker exec -i "$CONTAINER_ID" sh -c "mongorestore -d treestats-dev /data/mongodump/mongo"
docker exec "$CONTAINER_ID" sh -c 'mongo mongo --eval "db.dropDatabase()"'

echo "Done."

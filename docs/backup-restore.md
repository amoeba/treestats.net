# Backing + Restore

## Backup

`dokku mongo:export mongo-new > $location`
`dokku redis:export redis-new > $location`

## Restore

### Under Dokku

`dokku mongo:import mongo < asdf`

### Under standalone MongoDB

TODO

### Under Dockerized MongoDB

`docker exec -i 46b4ccdad542 sh -c 'mongorestore --gzip --archive' < backup.dokku.mongo-new.20210201`

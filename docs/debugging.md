# Debugging

## Export a server as JSON

`docker exec -i d2a1c202aec5 sh -c 'mongoexport -d=mongo-new -c=characters -q=\'{"s":"Frostcull"}\' --out=./data/export.json'`

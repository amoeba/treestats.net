# Testing

This project uses Minitest with MongoDB. Before running the test suite you must have a MongoDB server available. By default tests look for a server on `localhost:27017` and use the database `treestats-test`.

## Starting MongoDB

If you have Docker installed you can start a MongoDB container using the included `docker-compose.yml`:

```bash
docker compose up -d mongo
```

This exposes MongoDB on port `27017`. You can also run your own `mongod` instance locally if you prefer.

## Environment variables

Set `MONGO_URL` if you want the tests to use a custom connection string:

```bash
export MONGO_URL="mongodb://127.0.0.1:27017/treestats-test"
```

## Running the tests

Install dependencies and run the test suite with:

```bash
bundle install
bundle exec rake test
```

The suite will connect to the MongoDB instance as configured above.

# Testing

This project uses Minitest with MongoDB. **Tests will fail unless MongoDB is running**, so ensure a server is available before running the suite. By default tests look for a server on `localhost:27017` and use the database `treestats-test`.

## Starting MongoDB

If you have Docker installed you can start a MongoDB container using the included `docker-compose.yml`:

```bash
docker compose up -d mongo
```

This exposes MongoDB on port `27017`. You can also run your own `mongod` instance locally if you prefer.

For a minimal test setup you can create a short `docker-compose.yml` containing:

```yaml
services:
  mongo:
    image: mongo:5
    ports:
      - "27017:27017"
```

Start it with `docker compose up -d` to bring up a test database.

## Environment variables

Set `MONGO_URL` if you want the tests to use a custom connection string; see `config/mongoid.yml` for how this value is consumed:

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

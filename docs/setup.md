# Setup

## Prerequisites

- Ruby 3.4.9 (see `.ruby-version`)
- MongoDB 7
- Redis 7
- Bundler

## Local Development

### 1. Start services

```sh
docker-compose up -d
```

### 2. Install dependencies

```sh
bundle install
```

### 3. Run the app

```sh
bundle exec foreman start
```

The web process runs on `http://localhost:9292` by default. The Procfile starts four processes: `web`, `resque`, `clock`, and `sidekiq`. For basic development you only need `web`:

```sh
bundle exec puma
```

### 4. Run tests

```sh
bundle exec rake test
```

## Environment Variables

| Variable | Required | Description |
|---|---|---|
| `MONGO_URL` | production only | MongoDB connection URI |
| `REDIS_URL` | optional | Redis URL (defaults to `redis://localhost:6379`) |
| `SESSION_SECRET` | **required in production** | Cookie signing secret — must be ≥64 characters |
| `SIDEKIQ_WEB_USERNAME` | optional | Sidekiq dashboard username (defaults to `admin`) |
| `SIDEKIQ_WEB_PASSWORD` | optional | Sidekiq dashboard password — omit to disable the dashboard |
| `SENTRY_DSN` | optional | Sentry error reporting DSN (production only) |
| `UPLOAD_SAMPLE_RATE` | optional | Fraction of successful plugin uploads (`POST /`) to sample in Sentry, from `0` to `1`; defaults to `0` (off). Set at app boot; for 1%, use `0.01`. Each sampled event has a `character-upload.json` attachment containing the exact request body, including any `key` field. Direct server uploads to `POST /characters` are not sampled. |

## Admin Setup

The site has a single admin user used to archive characters and manage server
upload tokens.

### Create the admin

```sh
bundle exec rake admin:create
```

This prompts for a name and password (minimum 12 characters). The credential is stored as a bcrypt hash in MongoDB and can be re-run to reset the password.

### Log in

Visit `/admin/login` (not linked from anywhere). After signing in, an admin widget appears at the bottom-right corner of every character page, and an **Admin** link appears in the site footer. The dashboard at `/admin` shows data-polling status and issues server upload tokens.

See [Direct Uploads](direct-upload.md) for the token-authenticated upload API.

### Session secret

In production, set `SESSION_SECRET` to a random string of at least 64 characters:

```sh
export SESSION_SECRET=$(openssl rand -hex 64)
```

## Assets

In production, assets must be compiled before deploying:

```sh
bundle exec rake assets:precompile
```

This fingerprints and writes files to `public/assets/`.

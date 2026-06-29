# URL Shortener

A containerized URL shortening service (bit.ly-style) with an automated CI/CD pipeline.

When a long URL is submitted, the API generates a short code; visiting that code redirects to the original URL. The number of clicks per link is tracked in real time.

## Architecture

A multi-service application orchestrated with Docker Compose:

| Service | Role |
|---------|------|
| **Flask** | REST API (creation, redirection, statistics) |
| **nginx** | Reverse proxy in front of the application |
| **PostgreSQL** | Durable storage of links (code → URL) |
| **Redis** | Redirection cache and click counter |

Using two data stores is a deliberate choice: PostgreSQL durably stores the code/URL mapping (the source of truth), while Redis handles what needs to be fast and frequent — caching redirections (60 s expiry) and incrementing click counters.

## API Routes

| Method | Route | Description |
|--------|-------|-------------|
| `GET` | `/` | Service status |
| `POST` | `/shorten` | Creates a short link from a long URL |
| `GET` | `/<code>` | Redirects to the original URL (302) and increments clicks |
| `GET` | `/stats/<code>` | Returns the URL and click count for a link |

### Examples

Create a short link:
```bash
curl -X POST http://localhost/shorten \
  -H "Content-Type: application/json" \
  -d '{"url": "https://www.google.com"}'
# => {"code": "jMRYvK", "short_url": "/jMRYvK"}
```

Check statistics:
```bash
curl http://localhost/stats/jMRYvK
# => {"url": "https://www.google.com", "clicks": 2}
```

## Running Locally

Requirements: Docker and Docker Compose.

```bash
# 1. Create the .env file from the example
cp .env.example .env

# 2. Start the services
docker compose up --build

# 3. Initialize the database schema (links table)
docker compose exec -T database psql -U url_user -d url_name < init.sql
```

The API is then available at http://localhost (port 80, via nginx).

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push and pull request:

1. **Tests** — runs pytest against PostgreSQL and Redis service containers, with schema initialization. Includes integration tests that actually exercise the database and cache.
2. **Build** — builds the Docker images for the Flask and nginx services.
3. **Publish** — pushes the images to Docker Hub (only if tests pass).

Docker Hub credentials are managed via GitHub Secrets and never exposed in the code.

## Tech Stack

Python · Flask · PostgreSQL · Redis · Docker · Docker Compose · nginx · GitHub Actions

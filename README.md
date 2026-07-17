# URL Shortener

A containerized URL shortening service (bit.ly-style) with an automated CI/CD pipeline and a Prometheus/Grafana observability stack, deployed to AWS with Terraform.

When a long URL is submitted, the API generates a short code; visiting that code redirects to the original URL. The number of clicks per link is tracked in real time.

> **Live demo available on request.** The environment is provisioned on demand via Terraform.

## Architecture

A multi-service application orchestrated with Docker Compose:

| Service | Role |
|---------|------|
| **Flask** | REST API (creation, redirection, statistics) |
| **nginx** | Reverse proxy in front of the application |
| **PostgreSQL** | Durable storage of links (code → URL) |
| **Redis** | Redirection cache and click counter |
| **Prometheus** | Scrapes and stores application metrics |
| **Grafana** | Dashboards and visual alerting on those metrics |

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
```

The database schema (the `links` table) is initialized automatically on first
start: `init.sql` is mounted into the PostgreSQL container's
`/docker-entrypoint-initdb.d/` directory and runs when the data volume is
created. No manual step is required.

The API is then available at http://localhost (port 80, via nginx).

## Deployment (AWS + Terraform)

The application is deployed to AWS as Infrastructure-as-Code. All resources are
described in the [`terraform/`](./terraform) directory and provisioned with a
single `terraform apply`.

### Network flow

```
Browser
   │  http
   ▼
Elastic IP ──► Internet Gateway ──► Public subnet ──► EC2 (t4g.small)
                                                        │
                                              Docker Compose stack:
                                              nginx → flask → postgres / redis
```

### Resources provisioned

VPC · public subnet · internet gateway · route table · security group ·
SSH key pair · EC2 instance (Docker bootstrapped via cloud-init) · Elastic IP.

### Design decisions

- **Single-box deployment** — one `t4g.small` (ARM/Graviton) runs the whole
  Compose stack. No NAT Gateway, no load balancer, no managed database: the
  cheapest design that still demonstrates a full custom VPC.
- **Elastic IP** — gives the demo a stable public address across stop/start.
- **Least privilege on SSH** — port 22 is restricted to a single IP, while
  80/443 are open to the world.
- **Automated bootstrap** — a cloud-init `user-data` script installs Docker,
  clones this repository, and launches the stack, so the instance is
  self-configuring on first boot.

### Deploy

```bash
cd terraform
cp terraform.tfvars.example terraform.tfvars   # then set your IP
terraform init
terraform plan
terraform apply
```

Terraform outputs the public IP, the app URL, and a ready-to-use SSH command.
See [`terraform/README.md`](./terraform/README.md) for details and the
cost-control workflow.

## CI/CD Pipeline

The GitHub Actions workflow (`.github/workflows/ci.yml`) runs on every push and pull request:

1. **Tests** — runs pytest against PostgreSQL and Redis service containers, with schema initialization. Includes integration tests that actually exercise the database and cache.
2. **Build** — builds the Docker images for the Flask and nginx services.
3. **Publish** — pushes the images to Docker Hub (only if tests pass).

Docker Hub credentials are managed via GitHub Secrets and never exposed in the code.

## Observability

The stack ships with a full monitoring pipeline built on **Prometheus** and **Grafana**, so the service can be observed the way it would be in production instead of debugged blind.

### How it works

- The Flask app is instrumented with `prometheus-flask-exporter`, which exposes request metrics (count, latency, status codes) on a `/metrics` endpoint.
- **Prometheus** scrapes that endpoint every 15 s over the internal Docker network (`flask:5000`) and stores the time series. Its scrape configuration lives in [`prometheus.yml`](./prometheus.yml).
- **Grafana** reads from Prometheus as a data source and renders the dashboards. Dashboards and settings persist across restarts via a named Docker volume (`grafana_data`).

### Dashboard

A `url-shortener monitoring` dashboard tracks two key signals:

| Panel | Query | What it shows |
|-------|-------|---------------|
| **Request throughput** | `rate(flask_http_request_total[5m])` | Requests per second, split by method and status |
| **Error rate (%)** | `100 * sum(rate(flask_http_request_total{status=~"5.."}[5m])) / sum(rate(flask_http_request_total[5m]))` | Share of 5xx responses, with a red threshold at 5 % |

The error-rate panel turns red as soon as the value crosses 5 %, giving an at-a-glance health signal instead of a wall of numbers.

### Access

Once the stack is running:

- **Grafana** — http://localhost:3000 (default login `admin` / `admin`)
- **Prometheus** — http://localhost:9090 (query console and target health)

Flask's metrics endpoint is scraped internally over the Docker network and is not exposed publicly — only nginx faces the outside.

## Tech Stack

Python · Flask · PostgreSQL · Redis · Docker · Docker Compose · nginx · Prometheus · Grafana · GitHub Actions · AWS (EC2, VPC) · Terraform


## HTTPS setup (optional)

The default deployment serves the app over HTTP. To enable HTTPS on a running instance:

1. Point a domain at the instance's Elastic IP (e.g. a free DuckDNS subdomain).

2. Install certbot and issue a certificate (standalone mode):

```bash
   sudo apt-get install -y certbot
   sudo docker compose stop nginx
   sudo certbot certonly --standalone -d <your-domain> \
     --non-interactive --agree-tos -m <your-email>
   sudo docker compose start nginx
```

3. Activate the HTTPS config and rebuild:

```bash
   cp nginx/nginx-https.conf nginx/nginx.conf
   sudo docker compose up -d --build
```

Certbot sets up automatic renewal (certificates are valid for 90 days). The `nginx-https.conf` file contains the TLS-enabled server blocks: an HTTP→HTTPS redirect and the certificate configuration.

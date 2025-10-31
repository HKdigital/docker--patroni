# Complete Guide: Building Patroni with GitHub Actions

## Overview

Since there's no official Patroni Docker image, this guide shows you how to build and maintain your own using GitHub Actions and GitHub Container Registry (GHCR).

---

## Step 1: Create GitHub Repository

1. Go to https://github.com/new
2. Name it something like `patroni-docker`
3. Make it **Public** (for free GHCR hosting) or Private (still works, just different visibility)
4. Check "Add a README file"
5. Click "Create repository"

---

## Step 2: Create Repository Structure

Clone your repo locally:
```bash
git clone https://github.com/YOUR_USERNAME/patroni-docker.git
cd patroni-docker
```

Create the following file structure:
```
patroni-docker/
├── .github/
│   └── workflows/
│       └── build.yml
├── Dockerfile
└── README.md
```

---

## Step 3: Create the Dockerfile

Create `Dockerfile` with this content:

```dockerfile
FROM postgres:16-alpine

# Install Python and Patroni dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-psycopg2 \
    py3-yaml \
    && pip3 install --no-cache-dir --break-system-packages \
    patroni[etcd3]==3.3.2 \
    && mkdir -p /etc/patroni

# Expose PostgreSQL and Patroni API ports
EXPOSE 5432 8008

# Run as postgres user
USER postgres

# Start Patroni
CMD ["patroni", "/etc/patroni/patroni.yml"]
```

---

## Step 4: Create GitHub Actions Workflow

Create `.github/workflows/build.yml`:

```yaml
name: Build and Push Patroni Image

on:
  push:
    branches:
      - main
    paths:
      - 'Dockerfile'
      - '.github/workflows/build.yml'
  schedule:
    # Rebuild every Sunday at midnight UTC (gets latest security patches)
    - cron: '0 0 * * 0'
  workflow_dispatch:  # Allows manual triggering from GitHub UI

jobs:
  build:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      packages: write

    steps:
      - name: Checkout code
        uses: actions/checkout@v4

      - name: Set up Docker Buildx
        uses: docker/setup-buildx-action@v3

      - name: Log in to GitHub Container Registry
        uses: docker/login-action@v3
        with:
          registry: ghcr.io
          username: ${{ github.actor }}
          password: ${{ secrets.GITHUB_TOKEN }}

      - name: Extract metadata
        id: meta
        uses: docker/metadata-action@v5
        with:
          images: ghcr.io/${{ github.repository }}
          tags: |
            type=raw,value=latest
            type=sha,prefix={{branch}}-
            type=ref,event=branch

      - name: Build and push Docker image
        uses: docker/build-push-action@v5
        with:
          context: .
          push: true
          tags: ${{ steps.meta.outputs.tags }}
          labels: ${{ steps.meta.outputs.labels }}
          cache-from: type=gha
          cache-to: type=gha,mode=max
```

---

## Step 5: Create README.md

Create `README.md` with this content:

```markdown
# Patroni Docker Image

A production-ready Docker image for [Patroni](https://github.com/patroni/patroni) - a template for PostgreSQL High Availability with automatic failover.

Since there's no official Patroni Docker image, this repository provides an automated build using GitHub Actions and GitHub Container Registry.

## Quick Start

```bash
docker pull ghcr.io/YOUR_USERNAME/patroni-docker:latest
```

## What's Included

- **PostgreSQL 16** (Alpine-based for smaller image size)
- **Patroni 3.3.2** with etcd3 support
- **Python 3** and required dependencies
- Optimized for production use

## Usage

### Basic Docker Run

```bash
docker run -d \
  --name patroni \
  -p 5432:5432 \
  -p 8008:8008 \
  -e PATRONI_SCOPE=my-cluster \
  -e PATRONI_NAME=node1 \
  -e PATRONI_ETCD3_HOSTS=etcd:2379 \
  -v /path/to/patroni.yml:/etc/patroni/patroni.yml:ro \
  -v postgres-data:/var/lib/postgresql/data \
  ghcr.io/YOUR_USERNAME/patroni-docker:latest
```

### Docker Compose

```yaml
version: '3.8'

services:
  patroni:
    image: ghcr.io/YOUR_USERNAME/patroni-docker:latest
    container_name: patroni-node1
    hostname: node1
    ports:
      - "5432:5432"
      - "8008:8008"
    environment:
      # Cluster configuration
      PATRONI_SCOPE: my-cluster
      PATRONI_NAME: node1

      # etcd configuration
      PATRONI_ETCD3_HOSTS: etcd:2379

      # REST API
      PATRONI_RESTAPI_LISTEN: 0.0.0.0:8008
      PATRONI_RESTAPI_CONNECT_ADDRESS: node1:8008

      # PostgreSQL configuration
      PATRONI_POSTGRESQL_LISTEN: 0.0.0.0:5432
      PATRONI_POSTGRESQL_CONNECT_ADDRESS: node1:5432
      PATRONI_POSTGRESQL_DATA_DIR: /var/lib/postgresql/data

      # Authentication
      PATRONI_SUPERUSER_USERNAME: postgres
      PATRONI_SUPERUSER_PASSWORD: your-secure-password
      PATRONI_REPLICATION_USERNAME: replicator
      PATRONI_REPLICATION_PASSWORD: your-replication-password

      # PostgreSQL parameters
      PATRONI_POSTGRESQL_PARAMETERS_MAX_CONNECTIONS: 100
      PATRONI_POSTGRESQL_PARAMETERS_SHARED_BUFFERS: 1GB

    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./patroni.yml:/etc/patroni/patroni.yml:ro
    restart: unless-stopped

volumes:
  postgres-data:
```

## Configuration

Patroni can be configured through:

1. **Environment variables** (as shown above) - recommended for Docker
2. **Configuration file** mounted at `/etc/patroni/patroni.yml`

See [Patroni documentation](https://patroni.readthedocs.io/en/latest/SETTINGS.html) for all available options.

### Minimal Configuration File Example

```yaml
scope: my-cluster
name: node1

restapi:
  listen: 0.0.0.0:8008
  connect_address: node1:8008

etcd3:
  hosts: etcd:2379

bootstrap:
  dcs:
    ttl: 30
    loop_wait: 10
    retry_timeout: 10
    maximum_lag_on_failover: 1048576
    postgresql:
      use_pg_rewind: true
      parameters:
        max_connections: 100
        shared_buffers: 1GB

postgresql:
  listen: 0.0.0.0:5432
  connect_address: node1:5432
  data_dir: /var/lib/postgresql/data
  authentication:
    replication:
      username: replicator
      password: your-replication-password
    superuser:
      username: postgres
      password: your-secure-password
```

## Ports

- **5432**: PostgreSQL database
- **8008**: Patroni REST API

## Health Check

Check cluster status:
```bash
docker exec patroni patronictl list
```

Check via REST API:
```bash
curl http://localhost:8008/health
```

## Multi-Node Cluster Setup

To run a 3-node cluster, you'll need:

1. **etcd cluster** (3 nodes recommended)
2. **3 Patroni nodes** with unique names
3. **Network connectivity** between all nodes

Example with 3 nodes:

```yaml
# docker-compose.yml
version: '3.8'

services:
  patroni1:
    image: ghcr.io/YOUR_USERNAME/patroni-docker:latest
    environment:
      PATRONI_SCOPE: my-cluster
      PATRONI_NAME: node1
      # ... other config

  patroni2:
    image: ghcr.io/YOUR_USERNAME/patroni-docker:latest
    environment:
      PATRONI_SCOPE: my-cluster
      PATRONI_NAME: node2
      # ... other config

  patroni3:
    image: ghcr.io/YOUR_USERNAME/patroni-docker:latest
    environment:
      PATRONI_SCOPE: my-cluster
      PATRONI_NAME: node3
      # ... other config
```

## Image Variants

### Tags Available

- `latest` - Latest build from main branch (recommended for production with version pinning)
- `main-<sha>` - Specific commit SHA
- `main` - Latest from main branch

**Production Recommendation**: Pin to a specific SHA tag for reproducibility:
```yaml
image: ghcr.io/YOUR_USERNAME/patroni-docker:main-abc1234
```

## Building Locally

If you want to customize the image:

```bash
git clone https://github.com/YOUR_USERNAME/patroni-docker.git
cd patroni-docker
docker build -t patroni:custom .
```

## Updates

This image is automatically rebuilt:
- **On every commit** to the Dockerfile
- **Weekly** (Sundays at midnight UTC) to get latest security patches
- **Manually** via GitHub Actions workflow dispatch

To update your deployment:
```bash
docker pull ghcr.io/YOUR_USERNAME/patroni-docker:latest
docker-compose up -d
```

## Version Information

- Base Image: `postgres:16-alpine`
- Patroni Version: `3.3.2`
- Python Version: `3.x` (from Alpine)
- DCS Support: etcd3 (etcd2, Consul, and ZooKeeper can be added)

## Customization

### Different PostgreSQL Version

Edit `Dockerfile` and change:
```dockerfile
FROM postgres:15-alpine  # or postgres:14-alpine, etc.
```

### Add Additional Extensions

Edit `Dockerfile`:
```dockerfile
RUN apk add --no-cache \
    python3 \
    py3-pip \
    py3-psycopg2 \
    postgresql-contrib \
    # Add more packages here
```

### Different Patroni Version

Edit `Dockerfile`:
```dockerfile
patroni[etcd3]==3.2.0  # Change version
```

## Troubleshooting

### Container exits immediately
- Check logs: `docker logs patroni`
- Ensure etcd is reachable
- Verify configuration file syntax if using one

### Can't connect to PostgreSQL
- Verify ports are properly mapped
- Check firewall rules
- Ensure `PATRONI_POSTGRESQL_LISTEN` is set to `0.0.0.0:5432`

### Replication not working
- Verify replication user credentials
- Check network connectivity between nodes
- Ensure `max_wal_senders` and `max_replication_slots` are set properly

### Health check fails
- Check etcd connectivity
- Verify REST API is accessible: `curl http://localhost:8008/health`
- Check container logs for errors

## Security Considerations

- **Change default passwords** in production
- **Use secrets management** for sensitive credentials
- **Limit network exposure** using firewall rules
- **Keep image updated** by pulling regularly
- **Use TLS/SSL** for PostgreSQL and etcd connections in production

## Resources

- [Patroni Documentation](https://patroni.readthedocs.io/)
- [PostgreSQL Documentation](https://www.postgresql.org/docs/)
- [etcd Documentation](https://etcd.io/docs/)

## License

This Dockerfile and automation is provided as-is. Patroni and PostgreSQL have their own respective licenses.

## Contributing

Issues and pull requests are welcome! Please ensure:
- Dockerfile builds successfully
- Changes are tested locally
- Documentation is updated if needed

## Support

For issues with:
- **This Docker image**: Open an issue in this repository
- **Patroni itself**: Visit [Patroni GitHub](https://github.com/patroni/patroni)
- **PostgreSQL**: Visit [PostgreSQL Community](https://www.postgresql.org/community/)
```

**Don't forget to replace** `YOUR_USERNAME` with your actual GitHub username throughout the README!

---

## Step 6: Commit and Push

```bash
git add .
git commit -m "Add Patroni Docker image with GitHub Actions"
git push origin main
```

---

## Step 7: Watch the Build

1. Go to your GitHub repo
2. Click the **"Actions"** tab
3. You should see your workflow running
4. Click on it to watch the build progress
5. Wait ~2-5 minutes for it to complete

---

## Step 8: Verify the Image

Once the build completes:

1. Go to your repo's main page
2. Look for **"Packages"** in the right sidebar
3. Click on your `patroni-docker` package
4. You'll see the image URL: `ghcr.io/YOUR_USERNAME/patroni-docker:latest`

---

## Step 9: Make Image Public (if repo is public)

By default, GHCR packages inherit repo visibility, but double-check:

1. Click on your package
2. Click **"Package settings"** (bottom right)
3. Scroll to **"Danger Zone"**
4. Click **"Change visibility"**
5. Select **"Public"**
6. Confirm

---

## Step 10: Update Your docker-compose.yml

Replace your current patroni image with:

```yaml
services:
  patroni:
    image: ghcr.io/YOUR_USERNAME/patroni-docker:latest
    container_name: patroni-${NODE_NAME:-server}
    hostname: ${NODE_NAME:-server}
    networks:
      - patroni-net
    ports:
      - "${WIREGUARD_IP}:${POSTGRES_PORT}:5432"
      - "${WIREGUARD_IP}:${PATRONI_API_PORT}:8008"
    environment:
      # Cluster configuration
      PATRONI_SCOPE: ${CLUSTER_NAME}
      PATRONI_NAME: ${NODE_NAME}
      # etcd configuration
      PATRONI_ETCD3_HOSTS: ${ETCD_HOST}:${ETCD_PORT}
      # REST API
      PATRONI_RESTAPI_LISTEN: 0.0.0.0:8008
      PATRONI_RESTAPI_CONNECT_ADDRESS: ${WIREGUARD_IP}:${PATRONI_API_PORT}
      # PostgreSQL configuration
      PATRONI_POSTGRESQL_LISTEN: 0.0.0.0:5432
      PATRONI_POSTGRESQL_CONNECT_ADDRESS: ${WIREGUARD_IP}:${POSTGRES_PORT}
      PATRONI_POSTGRESQL_DATA_DIR: ${PGDATA}
      # Authentication
      PATRONI_SUPERUSER_USERNAME: postgres
      PATRONI_SUPERUSER_PASSWORD: ${POSTGRES_SUPERUSER_PASSWORD}
      PATRONI_REPLICATION_USERNAME: replicator
      PATRONI_REPLICATION_PASSWORD: ${REPLICATION_PASSWORD}
      # PostgreSQL parameters
      PATRONI_POSTGRESQL_PARAMETERS_MAX_CONNECTIONS: ${POSTGRES_MAX_CONNECTIONS:-100}
      PATRONI_POSTGRESQL_PARAMETERS_SHARED_BUFFERS: ${POSTGRES_SHARED_BUFFERS:-1GB}
      PATRONI_POSTGRESQL_PARAMETERS_EFFECTIVE_CACHE_SIZE: ${POSTGRES_EFFECTIVE_CACHE_SIZE:-3GB}
      PATRONI_POSTGRESQL_PARAMETERS_MAINTENANCE_WORK_MEM: 256MB
      PATRONI_POSTGRESQL_PARAMETERS_CHECKPOINT_COMPLETION_TARGET: 0.9
      PATRONI_POSTGRESQL_PARAMETERS_WAL_BUFFERS: 16MB
      PATRONI_POSTGRESQL_PARAMETERS_DEFAULT_STATISTICS_TARGET: 100
      PATRONI_POSTGRESQL_PARAMETERS_RANDOM_PAGE_COST: 1.1
      PATRONI_POSTGRESQL_PARAMETERS_EFFECTIVE_IO_CONCURRENCY: 200
      PATRONI_POSTGRESQL_PARAMETERS_WORK_MEM: 10MB
      PATRONI_POSTGRESQL_PARAMETERS_MIN_WAL_SIZE: 1GB
      PATRONI_POSTGRESQL_PARAMETERS_MAX_WAL_SIZE: 4GB
      # Replication settings
      PATRONI_POSTGRESQL_PARAMETERS_WAL_LEVEL: replica
      PATRONI_POSTGRESQL_PARAMETERS_HOT_STANDBY: "on"
      PATRONI_POSTGRESQL_PARAMETERS_MAX_WAL_SENDERS: 10
      PATRONI_POSTGRESQL_PARAMETERS_MAX_REPLICATION_SLOTS: 10
      PATRONI_POSTGRESQL_PARAMETERS_HOT_STANDBY_FEEDBACK: "on"
      # Logging
      PATRONI_POSTGRESQL_PARAMETERS_LOG_DESTINATION: stderr
      PATRONI_POSTGRESQL_PARAMETERS_LOGGING_COLLECTOR: "off"
      PATRONI_POSTGRESQL_PARAMETERS_LOG_STATEMENT: ${POSTGRES_LOG_STATEMENT:-none}
      PATRONI_POSTGRESQL_PARAMETERS_LOG_DURATION: "off"
      # Bootstrap configuration
      PATRONI_BOOTSTRAP_METHOD: ${BOOTSTRAP_METHOD:-auto}
      # Log level
      PATRONI_LOG_LEVEL: ${LOG_LEVEL:-INFO}
    volumes:
      - postgres-data:/var/lib/postgresql/data
      - ./configs/patroni.yml:/etc/patroni/patroni.yml:ro
    restart: unless-stopped
    healthcheck:
      test: ["CMD-SHELL", "patronictl list || exit 1"]
      interval: 10s
      timeout: 5s
      retries: 5
      start_period: 30s

volumes:
  postgres-data:
    driver: local
    driver_opts:
      type: none
      o: bind
      device: ${POSTGRES_DATA_PATH:-./data}

networks:
  patroni-net:
    driver: bridge
```

---

## Step 11: Pull and Run on Your Server

```bash
# On your server
docker pull ghcr.io/YOUR_USERNAME/patroni-docker:latest
docker-compose up -d
```

---

## Optional: Authentication for Private Images

If your repo/package is private, authenticate on your server:

```bash
# Create a Personal Access Token (PAT)
# Go to: GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
# Create token with 'read:packages' scope

# Login on your server
echo "YOUR_PAT" | docker login ghcr.io -u YOUR_USERNAME --password-stdin
```

---

## Updating the Image

Whenever you want to update:

1. **Edit the Dockerfile** locally
2. **Commit and push**:
   ```bash
   git add Dockerfile
   git commit -m "Update Patroni version"
   git push
   ```
3. **GitHub Actions builds automatically**
4. **Pull on your servers**:
   ```bash
   docker pull ghcr.io/YOUR_USERNAME/patroni-docker:latest
   docker-compose up -d
   ```

Or trigger a manual rebuild:
- Go to Actions tab → Click your workflow → Click "Run workflow"

---

## Troubleshooting

### Build fails with permission error
- Go to repo Settings → Actions → General → Workflow permissions
- Select "Read and write permissions"
- Save

### Can't pull image on server
- Make sure package is public OR you're logged in with a PAT
- Check the exact image URL in the Packages section

### Want different PostgreSQL version
- Change `FROM postgres:16-alpine` to `FROM postgres:15-alpine` (or any version)
- Commit and push

---

## Why GitHub Actions + GHCR?

**Advantages:**
- ✅ Free hosting (public images)
- ✅ Automated rebuilds when you push changes
- ✅ Version control for your Dockerfile
- ✅ Can make images private if needed
- ✅ No manual builds on servers
- ✅ Easy to update all servers at once
- ✅ Weekly automatic rebuilds for security patches

**Alternatives considered:**
- Building on server during installation (manual, not reproducible)
- Docker Hub (similar but requires separate account)
- Pre-built image distribution (harder to update)

---

## Summary

1. Create GitHub repo
2. Add Dockerfile, workflow, and README
3. Push to GitHub
4. Wait for automatic build
5. Use image in your docker-compose
6. Updates happen automatically or on-demand

Your image will be available at: `ghcr.io/YOUR_USERNAME/patroni-docker:latest`

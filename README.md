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

- `latest` - Latest build from main branch
- `main-<sha>` - Specific commit SHA
- `main` - Latest from main branch

**Production Recommendation**: Pin to a specific SHA tag for reproducibility:
```yaml
image: ghcr.io/YOUR_USERNAME/patroni-docker:main-abc1234
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
- DCS Support: etcd3

## Customization

### Different PostgreSQL Version

Fork this repo, edit `Dockerfile` and change:
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

## Building Locally

If you want to build the image yourself:

```bash
git clone https://github.com/YOUR_USERNAME/patroni-docker.git
cd patroni-docker
docker build -t patroni:custom .
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

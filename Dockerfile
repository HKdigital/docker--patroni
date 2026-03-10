FROM postgis/postgis:16-3.4-alpine

# Install Python and build dependencies
RUN apk add --no-cache \
    python3 \
    py3-pip \
    gcc \
    python3-dev \
    musl-dev \
    linux-headers \
    postgresql-dev \
    libpq-dev

# Install Patroni
RUN pip3 install --no-cache-dir --break-system-packages \
    patroni[etcd3]==3.3.2 \
    psycopg2-binary

# Clean up build dependencies (optional - saves ~50MB)
RUN apk del gcc python3-dev musl-dev

# Create config directory
RUN mkdir -p /etc/patroni

# Expose PostgreSQL and Patroni API ports
EXPOSE 5432 8008

# Run as postgres user
USER postgres

# Start Patroni
CMD ["patroni", "/etc/patroni/patroni.yml"]

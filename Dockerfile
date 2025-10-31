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

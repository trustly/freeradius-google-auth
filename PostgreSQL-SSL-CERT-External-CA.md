# Howto setup PostgreSQL with external SSL-cert CA

For maximum security, the CA should be a separate offline machine not used for
anything else than the signing of SSL certificates.

## 1. CA

The CA should be an offline computer locked in a safe.

### 1.1. Generate CA private key

    sudo openssl genrsa -des3 -out /etc/ssl/private/trustly-ca.key 2048
    sudo chown root:ssl-cert /etc/ssl/private/trustly-ca.key
    sudo chmod 640 /etc/ssl/private/trustly-ca.key

### 1.2. Generate CA public certificate

    sudo openssl req -new -x509 -days 3650 \
    -subj '/C=SE/ST=Stockholm/L=Stockholm/O=Trustly/CN=trustly' \
    -key /etc/ssl/private/trustly-ca.key \
    -out /usr/local/share/ca-certificates/trustly-ca.crt
    sudo update-ca-certificates

## 2. PostgreSQL-server

### 2.1. Generate PostgreSQL-server private key

    # Remove default snakeoil certs
    sudo rm /var/lib/postgresql/9.1/main/server.key
    sudo rm /var/lib/postgresql/9.1/main/server.crt
    # Enter a passphrase
    sudo -u postgres openssl genrsa -des3 -out /var/lib/postgresql/9.1/main/server.key 2048
    # Remove the passphrase
    sudo -u postgres openssl rsa -in /var/lib/postgresql/9.1/main/server.key -out /var/lib/postgresql/9.1/main/server.key
    sudo -u postgres chmod 400 /var/lib/postgresql/9.1/main/server.key

### 2.2. Request CA to sign PostgreSQL-server key

    sudo -u postgres openssl req -new -nodes -key /var/lib/postgresql/9.1/main/server.key -days 3650 -out /tmp/server.csr -subj '/C=SE/ST=Stockholm/L=Stockholm/O=Trustly/CN=postgres'

### 2.3. Sign PostgreSQL-server key with CA private key

    sudo openssl req -x509 \
    -key /etc/ssl/private/trustly-ca.key \
    -in /tmp/server.csr \
    -out /var/lib/postgresql/9.1/main/server.crt
    sudo chown postgres:postgres /var/lib/postgresql/9.1/main/server.crt

### 2.4. Create root cert = PostgreSQL-server cert + CA cert

    sudo -u postgres sh -c 'cat /var/lib/postgresql/9.1/main/server.crt /etc/ssl/certs/trustly-ca.pem > /var/lib/postgresql/9.1/main/root.crt'
    sudo cp /var/lib/postgresql/9.1/main/root.crt /usr/local/share/ca-certificates/trustly-postgresql.crt
    sudo update-ca-certificates

### 2.5. Require SSL client certs

    # Edit /etc/postgresql/9.1/main/pg_hba.conf:
    hostssl <database> <user> <address> cert clientcert=1
    # Example:
    hostssl trustly joel 192.168.1.0/24 cert clientcert=1

### 2.6. Restart PostgreSQL

    sudo service postgresql restart

## 3. PostgreSQL-client(s)

### 3.1. Copy root cert from PostgreSQL-server

    mkdir ~/.postgresql
    cp /etc/ssl/certs/trustly-postgresql.pem ~/.postgresql/root.crt

### 3.2. Generate PostgreSQL-client private key

    openssl genrsa -des3 -out ~/.postgresql/postgresql.key 1024

    # If this is a server, remove the passphrase:
    openssl rsa -in ~/.postgresql/postgresql.key -out ~/.postgresql/postgresql.key

### 3.3. Request CA to sign PostgreSQL-client key

    # Replace "joel" with username:
    openssl req -new -key ~/.postgresql/postgresql.key -out ~/.postgresql/postgresql.csr -subj '/C=SE/ST=Stockholm/L=Stockholm/O=Trustly/CN=joel'
    sudo openssl x509 -req -in ~/.postgresql/postgresql.csr -CA /etc/ssl/certs/trustly-ca.pem -CAkey /etc/ssl/private/trustly-ca.key -out ~/.postgresql/postgresql.crt -CAcreateserial
    sudo chown joel:joel -R ~/.postgresql
    sudo chmod 400 -R ~/.postgresql/postgresql.key

## 4. Files

The following files are created/modififed on each machine:

### 4.1. CA

    /etc/ssl/private/trustly-ca.key
    /usr/local/share/ca-certificates/trustly-ca.crt
    /etc/ssl/certs/trustly-ca.pem -> /usr/local/share/ca-certificates/trustly-ca.crt

### 4.2. PostgreSQL-server

    /var/lib/postgresql/9.1/main/server.key
    /var/lib/postgresql/9.1/main/server.crt
    /var/lib/postgresql/9.1/main/root.crt
    /usr/local/share/ca-certificates/trustly-ca.crt
    /usr/local/share/ca-certificates/trustly-postgresql.crt
    /etc/ssl/certs/trustly-ca.pem -> /usr/local/share/ca-certificates/trustly-ca.crt
    /etc/ssl/certs/trustly-postgresql.pem -> /usr/local/share/ca-certificates/trustly-postgresql.crt
    /etc/postgresql/9.1/main/pg_hba.conf

### 4.3. PostgreSQL-client

    ~/.postgresql/root.crt
    ~/.postgresql/postgresql.key
    ~/.postgresql/postgresql.crt


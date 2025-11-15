# Local SSL/HTTPS Setup

## Quick Summary

- **Local Development (.local domains)**: HTTP is standard - zero configuration needed
- **Testing HTTPS Features**: Use mkcert for locally-trusted certificates
- **Production**: Let's Encrypt (already configured in Traefik)

---

## Setup HTTPS with mkcert (Optional)

Use this if you need to test HTTPS-specific browser features (Service Workers, PWA, WebRTC, etc.)

### 1. Install mkcert on Mac

```bash
brew install mkcert
mkcert -install
```

### 2. Generate Certificates

```bash
cd ~/mini-server/traefik/certs

# Generate wildcard cert for all .local domains
mkcert \
  "*.local" \
  "localhost" \
  "127.0.0.1" \
  "192.168.1.10"

# Rename for Traefik
mv _wildcard.local+3.pem local-cert.pem
mv _wildcard.local+3-key.pem local-key.pem
```

### 3. Configure Traefik

Edit `traefik/traefik.yml`:

```yaml
# Add TLS configuration
tls:
  certificates:
    - certFile: /certs/local-cert.pem
      keyFile: /certs/local-key.pem
```

Edit `traefik/docker-compose.yml`:

```yaml
services:
  traefik:
    volumes:
      - ./certs:/certs:ro  # Add this line
```

### 4. Enable HTTPS in Projects

Uncomment HTTPS routes in your project's `docker-compose.yml`:

```yaml
labels:
  # Enable HTTPS
  - "traefik.http.routers.PROJECT-web-secure.rule=Host(`project.local`)"
  - "traefik.http.routers.PROJECT-web-secure.entrypoints=websecure"
  - "traefik.http.routers.PROJECT-web-secure.tls=true"

  # Optional: Redirect HTTP → HTTPS
  - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"
  - "traefik.http.routers.PROJECT-web.middlewares=redirect-to-https"
```

### 5. Restart Services

```bash
ssh asus-server 'cd /opt/traefik && docker-compose restart'
cd /opt/projects/your-project && docker-compose restart
```

Now your .local domain will work with HTTPS and no browser warnings!

---

## Production HTTPS

For production domains, use Let's Encrypt (already configured in Traefik):

1. Get a real domain (e.g., `app.yourdomain.com`)
2. Point DNS to your server's public IP
3. Uncomment Let's Encrypt config in `traefik/traefik.yml`
4. Traefik automatically obtains and renews certificates

---

## Quick Reference

| Scenario | Solution |
|----------|----------|
| Local dev (.local) | HTTP (default) |
| Test HTTPS features | mkcert (this guide) |
| Production | Let's Encrypt (automatic) |

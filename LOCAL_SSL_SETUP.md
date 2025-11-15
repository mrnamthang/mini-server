# SSL/HTTPS for .local Domains

## TL;DR: HTTP is Fine for Local Development

**For `.local` domains, HTTP (not HTTPS) is the standard and recommended approach.**

Why? `.local` domains:
- Cannot get Let's Encrypt certificates (not publicly resolvable)
- Require self-signed certs (browser warnings) or local CA setup
- Are only accessible on your local network (not exposed to internet)

**HTTPS is important for production, but unnecessary overhead for local dev.**

---

## Why You're Seeing HTTP (Not a Problem!)

When you visit `http://tradewhispr.local`, you're using HTTP because:

1. ✅ `.local` is a local network domain
2. ✅ Traffic never leaves your network
3. ✅ No security risk (Mac ↔ Asus on private network)
4. ✅ Industry standard for local development

**Examples of companies using HTTP for local dev:**
- Facebook uses `facebook.localhost` (HTTP)
- Airbnb uses `*.airbnb.dev.local` (HTTP)
- Most Docker/Kubernetes local setups use HTTP

---

## When You NEED HTTPS

### Production (Public Internet)
✅ **Use Let's Encrypt** - Free, automatic, trusted certificates

Already configured in your Traefik setup! Just:
1. Get a real domain (e.g., `tradewhispr.yourdomain.com`)
2. Point DNS to your Asus public IP
3. Traefik automatically gets Let's Encrypt cert
4. HTTPS works!

### Testing HTTPS Features Locally (PWA, Service Workers, etc.)
Some browser APIs require HTTPS. If you need this for local development:

---

## Option 1: Use mkcert (If You Really Want Local HTTPS)

`mkcert` creates locally-trusted certificates for development.

### Setup (10 minutes)

#### 1. Install mkcert on Mac

```bash
brew install mkcert
mkcert -install
```

#### 2. Generate Certificates

```bash
cd ~/mini-server/traefik/certs

# Generate certs for all your .local domains
mkcert \
  "*.local" \
  "tradewhispr.local" \
  "api.tradewhispr.local" \
  "flow.local" \
  "api.flow.local" \
  "localhost" \
  "127.0.0.1" \
  "192.168.1.10"

# Rename for Traefik
mv _wildcard.local+7.pem local-cert.pem
mv _wildcard.local+7-key.pem local-key.pem
```

#### 3. Update Traefik Configuration

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

#### 4. Update Project docker-compose.yml

Uncomment HTTPS routes in `projects/tradewhispr/docker-compose.yml`:

```yaml
labels:
  # Enable HTTPS
  - "traefik.http.routers.tradewhispr-web-secure.rule=Host(`tradewhispr.local`)"
  - "traefik.http.routers.tradewhispr-web-secure.entrypoints=websecure"
  - "traefik.http.routers.tradewhispr-web-secure.tls=true"

  # Redirect HTTP → HTTPS
  - "traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https"
  - "traefik.http.routers.tradewhispr-web.middlewares=redirect-to-https"
```

#### 5. Restart Traefik

```bash
ssh asus-server 'cd /opt/traefik && docker-compose restart'
```

#### 6. Access via HTTPS

Now works:
- ✅ https://tradewhispr.local (no browser warning!)
- ✅ https://api.tradewhispr.local
- ✅ https://flow.local

### Pros:
- ✅ No browser warnings
- ✅ Trusted certificates
- ✅ Test HTTPS-only features

### Cons:
- ❌ Extra setup complexity
- ❌ Certificates expire (need renewal)
- ❌ Only works on devices that trust your mkcert CA
- ❌ Not necessary for most local development

---

## Option 2: Self-Signed Certificates (Not Recommended)

You can create self-signed certs, but browsers will show scary warnings:
- "Your connection is not private"
- "NET::ERR_CERT_AUTHORITY_INVALID"

Users have to click "Advanced" → "Proceed anyway" every time.

**Don't do this.** Use mkcert instead if you need HTTPS.

---

## Option 3: Just Use HTTP (Recommended!)

**This is what most developers do for local work.**

### Benefits:
- ✅ Zero configuration
- ✅ Works immediately
- ✅ No certificate management
- ✅ No browser warnings
- ✅ Faster (no TLS overhead)

### When it's fine:
- ✅ Local network only (Mac ↔ Asus)
- ✅ Not testing HTTPS-specific features
- ✅ Regular web development
- ✅ API development
- ✅ Database-backed apps

### When you need HTTPS:
- ❌ Testing Service Workers
- ❌ Testing PWA features
- ❌ Testing WebRTC
- ❌ Testing Secure contexts APIs
- ❌ Testing HTTP/2 push

For these cases, use mkcert (Option 1).

---

## Recommended Approach

### For Local Development (Current Setup)
**Use HTTP** - It's perfect for your workflow:
```
http://tradewhispr.local
http://api.tradewhispr.local
http://flow.local
```

### For Production (When Ready)
**Use Let's Encrypt** (already configured!):
1. Get domain: `tradewhispr.yourdomain.com`
2. Point DNS to Asus public IP
3. Uncomment Let's Encrypt config in Traefik
4. Automatic HTTPS!

---

## Summary

| Scenario | Solution |
|----------|----------|
| Local dev (.local) | HTTP (current setup) ✅ |
| Need to test HTTPS features | mkcert |
| Production (real domain) | Let's Encrypt (built-in) |

**Your current HTTP setup is correct and follows best practices!**

---

## Fixing Your 404 (Not SSL Issue)

The 404 you're seeing is unrelated to HTTPS. Run this to diagnose:

```bash
./scripts/troubleshoot-404.sh tradewhispr
```

Common causes:
1. Containers not running
2. /etc/hosts not configured
3. Traefik not routing correctly

SSL won't fix the 404 - we need to troubleshoot routing first!

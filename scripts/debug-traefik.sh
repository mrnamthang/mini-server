#!/bin/bash
# Debug Traefik issues

set -e

ASUS_HOST="asus-server"

echo "🔍 Checking Traefik status..."
echo ""

echo "1. Is Traefik container running?"
ssh "$ASUS_HOST" "docker ps --filter name=traefik --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'"

echo ""
echo "2. All containers (including stopped):"
ssh "$ASUS_HOST" "docker ps -a --filter name=traefik --format 'table {{.Names}}\t{{.Status}}'"

echo ""
echo "3. Traefik logs (last 50 lines):"
ssh "$ASUS_HOST" "docker logs traefik --tail 50 2>&1 || echo 'Container not found or error reading logs'"

echo ""
echo "4. Check if port 8080 is accessible:"
ssh "$ASUS_HOST" "netstat -tuln | grep 8080 || echo 'Port 8080 not listening'"

echo ""
echo "5. Check Traefik configuration file:"
ssh "$ASUS_HOST" "cat /opt/traefik/traefik.yml | head -20"

echo ""
echo "6. Check if acme.json has correct permissions:"
ssh "$ASUS_HOST" "ls -la /opt/traefik/acme.json"

echo ""
echo "=== Suggested fixes ==="
echo ""
echo "If container is not running:"
echo "  ssh thang@192.168.1.10"
echo "  cd /opt/traefik"
echo "  docker-compose up -d"
echo ""
echo "If container is restarting:"
echo "  Check logs above for errors"
echo "  Common issue: acme.json permissions"
echo "  Fix: sudo chmod 600 /opt/traefik/acme.json"
echo ""
echo "If port 8080 conflict:"
echo "  Change port in traefik/docker-compose.yml"
echo "  Or stop service using port 8080"

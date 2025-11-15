#!/bin/bash
# Fix port 80 conflict by stopping web servers

set -e

ASUS_HOST="asus-server"

echo "🔍 Checking what's using port 80..."
ssh "$ASUS_HOST" "sudo lsof -i :80" || echo "Nothing found with lsof, checking services..."

echo ""
echo "🛑 Stopping common web servers..."

# Stop and disable nginx
ssh "$ASUS_HOST" "sudo systemctl stop nginx 2>/dev/null || true"
ssh "$ASUS_HOST" "sudo systemctl disable nginx 2>/dev/null || true"

# Stop and disable apache2
ssh "$ASUS_HOST" "sudo systemctl stop apache2 2>/dev/null || true"
ssh "$ASUS_HOST" "sudo systemctl disable apache2 2>/dev/null || true"

echo ""
echo "✅ Web servers stopped"
echo ""
echo "Verify port 80 is free:"
ssh "$ASUS_HOST" "sudo lsof -i :80" && echo "❌ Port 80 still in use!" || echo "✅ Port 80 is free!"

echo ""
echo "Now run: make traefik"

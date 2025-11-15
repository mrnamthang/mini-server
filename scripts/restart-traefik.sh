#!/bin/bash
# Aggressively fix port 80 and restart Traefik

set -e

ASUS_HOST="thang@192.168.1.10"

echo "🔍 Checking what's using port 80..."
ssh "$ASUS_HOST" "sudo lsof -i :80" || echo "Nothing found with lsof"

echo ""
echo "🛑 Killing all processes on port 80..."
ssh "$ASUS_HOST" "sudo fuser -k 80/tcp 2>/dev/null || true"

echo ""
echo "🛑 Stopping and disabling common web servers..."
ssh "$ASUS_HOST" "sudo systemctl stop nginx 2>/dev/null || true"
ssh "$ASUS_HOST" "sudo systemctl disable nginx 2>/dev/null || true"
ssh "$ASUS_HOST" "sudo systemctl stop apache2 2>/dev/null || true"
ssh "$ASUS_HOST" "sudo systemctl disable apache2 2>/dev/null || true"
ssh "$ASUS_HOST" "sudo systemctl stop lighttpd 2>/dev/null || true"
ssh "$ASUS_HOST" "sudo systemctl disable lighttpd 2>/dev/null || true"

echo ""
echo "⏸️  Waiting 2 seconds..."
sleep 2

echo ""
echo "✅ Verifying port 80 is free..."
if ssh "$ASUS_HOST" "sudo lsof -i :80"; then
    echo "❌ Port 80 still in use! Manual intervention needed."
    echo ""
    echo "Run this to find the process:"
    echo "  ssh $ASUS_HOST 'sudo lsof -i :80'"
    echo "Then kill it manually or reboot the server"
    exit 1
else
    echo "✅ Port 80 is free!"
fi

echo ""
echo "🚀 Starting Traefik..."
ssh "$ASUS_HOST" "cd /opt/traefik && docker-compose up -d"

echo ""
echo "⏸️  Waiting for Traefik to start..."
sleep 5

echo ""
echo "📊 Checking Traefik status..."
ssh "$ASUS_HOST" "docker ps | grep traefik"

echo ""
echo "✅ Done! Access Traefik at: http://traefik.local"

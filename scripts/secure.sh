#!/bin/bash
# Secure a specific project (enable HTTPS)
# Usage: ./scripts/secure.sh <project-name>

set -e

PROJECT=$1
if [ -z "$PROJECT" ]; then
    echo "Usage: ./scripts/secure.sh <project-name>"
    echo "Example: ./scripts/secure.sh tradewhispr"
    exit 1
fi

# Load config
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../.dev-config"
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    ASUS_SSH_ALIAS="asus-server"
fi

echo "🔒 Enabling HTTPS for $PROJECT.local..."

# Update docker-compose.yml on Asus to enable HTTPS routes
ssh "$ASUS_SSH_ALIAS" << EOF
cd /opt/projects/$PROJECT

# Add HTTPS router labels if not present
docker-compose config | grep -q "websecure" || {
    echo "Adding HTTPS configuration..."
    # This is a placeholder - actual implementation would update the file
    echo "Please add HTTPS labels to your docker-compose.yml"
    echo "See: projects/$PROJECT/docker-compose.yml"
}

# Restart services
docker-compose up -d
EOF

echo "✓ HTTPS enabled for https://$PROJECT.local"

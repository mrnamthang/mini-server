#!/bin/bash
# Project manager - Start/stop projects on Asus server

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m'

ASUS_HOST="asus-server"

# Available projects (update this list)
PROJECTS=(
    "flow"
    "tradewhispr"
    "client-a"
    "client-b"
    "client-c"
    "client-d"
)

show_status() {
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}📊 Project Status on Asus Server${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""

    ssh "$ASUS_HOST" "docker ps --format 'table {{.Names}}\t{{.Status}}' | grep -v traefik || echo 'No projects running'"

    echo ""
    echo -e "${YELLOW}Resource Usage:${NC}"
    ssh "$ASUS_HOST" "free -h | grep Mem"

    echo ""
}

start_project() {
    local project=$1
    echo -e "${GREEN}▶️  Starting $project...${NC}"
    ssh "$ASUS_HOST" "cd /opt/projects/$project && docker-compose up -d"
    echo -e "${GREEN}✅ $project started${NC}"
    echo "Access: http://$project.local"
    echo ""
}

stop_project() {
    local project=$1
    echo -e "${YELLOW}⏹  Stopping $project...${NC}"
    ssh "$ASUS_HOST" "cd /opt/projects/$project && docker-compose down"
    echo -e "${GREEN}✅ $project stopped${NC}"
    echo ""
}

stop_all() {
    echo -e "${YELLOW}⏹  Stopping all projects...${NC}"
    echo ""
    for project in "${PROJECTS[@]}"; do
        ssh "$ASUS_HOST" "cd /opt/projects/$project && docker-compose down 2>/dev/null || true"
        echo "  ✓ $project stopped"
    done
    echo ""
    echo -e "${GREEN}✅ All projects stopped${NC}"
    echo ""
}

list_projects() {
    echo -e "${BLUE}Available projects:${NC}"
    for project in "${PROJECTS[@]}"; do
        echo "  - $project"
    done
    echo ""
}

# Main command
case "$1" in
    status)
        show_status
        ;;
    start)
        if [ -z "$2" ]; then
            echo "Usage: $0 start <project-name>"
            list_projects
            exit 1
        fi
        start_project "$2"
        show_status
        ;;
    stop)
        if [ -z "$2" ]; then
            echo "Usage: $0 stop <project-name>"
            list_projects
            exit 1
        fi
        stop_project "$2"
        show_status
        ;;
    stop-all)
        stop_all
        show_status
        ;;
    restart)
        if [ -z "$2" ]; then
            echo "Usage: $0 restart <project-name>"
            list_projects
            exit 1
        fi
        stop_project "$2"
        start_project "$2"
        show_status
        ;;
    list)
        list_projects
        ;;
    *)
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo -e "${GREEN}Project Manager - Asus Server${NC}"
        echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
        echo ""
        echo "Usage: $0 <command> [project-name]"
        echo ""
        echo "Commands:"
        echo "  status                 - Show running projects and resources"
        echo "  list                   - List all available projects"
        echo "  start <project>        - Start a specific project"
        echo "  stop <project>         - Stop a specific project"
        echo "  stop-all               - Stop all projects"
        echo "  restart <project>      - Restart a specific project"
        echo ""
        echo "Examples:"
        echo "  $0 status"
        echo "  $0 start flow"
        echo "  $0 stop client-a"
        echo "  $0 restart tradewhispr"
        echo "  $0 stop-all"
        echo ""
        list_projects
        ;;
esac

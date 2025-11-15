.PHONY: help setup bootstrap docker traefik deploy-flow deploy-tradewhispr deploy-all \
        update-system restart-traefik restart-flow restart-tradewhispr \
        logs-flow logs-tradewhispr ping check facts clean

# Variables
ANSIBLE_DIR = ansible
INVENTORY = $(ANSIBLE_DIR)/inventory/hosts.yml
PLAYBOOK_DIR = $(ANSIBLE_DIR)/playbooks

# Colors for output
RED = \033[0;31m
GREEN = \033[0;32m
YELLOW = \033[0;33m
BLUE = \033[0;34m
NC = \033[0m # No Color

# Default target
.DEFAULT_GOAL := help

##@ General

help: ## Display this help message
	@echo "$(BLUE)Mini Server Infrastructure - Makefile Commands$(NC)"
	@echo ""
	@awk 'BEGIN {FS = ":.*##"; printf "Usage:\n  make $(CYAN)<target>$(NC)\n"} /^[a-zA-Z_0-9-]+:.*?##/ { printf "  $(CYAN)%-20s$(NC) %s\n", $$1, $$2 } /^##@/ { printf "\n$(YELLOW)%s$(NC)\n", substr($$0, 5) } ' $(MAKEFILE_LIST)

##@ Infrastructure Setup

setup: ## Complete setup (bootstrap + docker + traefik)
	@echo "$(GREEN)Starting complete mini-server setup...$(NC)"
	@$(MAKE) bootstrap
	@$(MAKE) docker
	@$(MAKE) traefik
	@echo "$(GREEN)✅ Complete setup finished!$(NC)"
	@echo ""
	@echo "$(YELLOW)Next steps:$(NC)"
	@echo "  1. Update ansible/inventory/hosts.yml with your server IP"
	@echo "  2. Deploy projects: make deploy-flow or make deploy-tradewhispr"
	@echo "  3. Add domains to /etc/hosts on your Mac"

bootstrap: ## Initial server configuration (security, packages, directories)
	@echo "$(GREEN)Running bootstrap playbook...$(NC)"
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/01-bootstrap.yml

docker: ## Install Docker and Docker Compose
	@echo "$(GREEN)Installing Docker...$(NC)"
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/02-docker.yml

traefik: ## Setup Traefik reverse proxy
	@echo "$(GREEN)Setting up Traefik...$(NC)"
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/03-traefik.yml

##@ Project Deployment

deploy-flow: ## Deploy Flow project (.NET 8 + React)
	@echo "$(GREEN)Deploying Flow project...$(NC)"
	@echo "$(YELLOW)Note: Ensure Flow source code is in /opt/projects/flow/src on the server$(NC)"
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/deploy-project.yml -e "project=flow"

deploy-tradewhispr: ## Deploy Tradewhispr project (FastAPI + Vue 3)
	@echo "$(GREEN)Deploying Tradewhispr project...$(NC)"
	@echo "$(YELLOW)Note: Ensure Tradewhispr source code is in /opt/projects/tradewhispr/src on the server$(NC)"
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/deploy-project.yml -e "project=tradewhispr"

deploy-all: deploy-flow deploy-tradewhispr ## Deploy all projects

##@ Maintenance

update-system: ## Update server packages and security patches
	@echo "$(GREEN)Updating system packages...$(NC)"
	ansible mini_servers -i $(INVENTORY) -m apt -a "update_cache=yes upgrade=dist" -b

restart-traefik: ## Restart Traefik reverse proxy
	@echo "$(GREEN)Restarting Traefik...$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "cd /opt/traefik && docker-compose restart" -b

restart-flow: ## Restart Flow services
	@echo "$(GREEN)Restarting Flow services...$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "cd /opt/projects/flow && docker-compose restart" -b

restart-tradewhispr: ## Restart Tradewhispr services
	@echo "$(GREEN)Restarting Tradewhispr services...$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "cd /opt/projects/tradewhispr && docker-compose restart" -b

stop-flow: ## Stop Flow services
	@echo "$(YELLOW)Stopping Flow services...$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "cd /opt/projects/flow && docker-compose down" -b

stop-tradewhispr: ## Stop Tradewhispr services
	@echo "$(YELLOW)Stopping Tradewhispr services...$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "cd /opt/projects/tradewhispr && docker-compose down" -b

##@ Logs

logs-flow: ## View Flow logs (last 100 lines)
	@echo "$(BLUE)Flow logs:$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "cd /opt/projects/flow && docker-compose logs --tail=100" -b

logs-tradewhispr: ## View Tradewhispr logs (last 100 lines)
	@echo "$(BLUE)Tradewhispr logs:$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "cd /opt/projects/tradewhispr && docker-compose logs --tail=100" -b

logs-traefik: ## View Traefik logs (last 100 lines)
	@echo "$(BLUE)Traefik logs:$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "docker logs traefik --tail=100" -b

##@ Utilities

ping: ## Test connectivity to server
	@echo "$(GREEN)Testing connectivity...$(NC)"
	ANSIBLE_BECOME=false ansible mini_servers -i $(INVENTORY) -m ping

check: ## Check Ansible configuration
	@echo "$(GREEN)Checking Ansible configuration...$(NC)"
	ansible-playbook -i $(INVENTORY) $(PLAYBOOK_DIR)/01-bootstrap.yml --check

facts: ## Gather server facts
	@echo "$(GREEN)Gathering server facts...$(NC)"
	ANSIBLE_BECOME=false ansible mini_servers -i $(INVENTORY) -m setup

status: ## Show status of all services
	@echo "$(BLUE)Server Status:$(NC)"
	@echo ""
	@echo "$(YELLOW)Docker Containers:$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "docker ps --format 'table {{.Names}}\t{{.Status}}\t{{.Ports}}'" -b

disk-usage: ## Show disk usage on server
	@echo "$(BLUE)Disk Usage:$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "df -h" -b

docker-stats: ## Show Docker resource usage
	@echo "$(BLUE)Docker Stats:$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "docker stats --no-stream" -b

##@ Cleanup

clean-docker: ## Clean up Docker (remove unused containers, images, volumes)
	@echo "$(YELLOW)⚠️  Warning: This will remove unused Docker resources$(NC)"
	@read -p "Are you sure? [y/N] " -n 1 -r; \
	echo; \
	if [[ $$REPLY =~ ^[Yy]$$ ]]; then \
		ansible mini_servers -i $(INVENTORY) -m shell -a "docker system prune -af --volumes" -b; \
	fi

clean: ## Clean local Ansible cache
	@echo "$(GREEN)Cleaning local cache...$(NC)"
	rm -rf $(ANSIBLE_DIR)/.ansible_cache
	rm -rf $(ANSIBLE_DIR)/*.retry

##@ Configuration

edit-inventory: ## Edit inventory file
	$$EDITOR $(INVENTORY)

edit-vars: ## Edit global variables
	$$EDITOR $(ANSIBLE_DIR)/group_vars/all.yml

##@ SSH Access

ssh: ## SSH into the Asus server
	@echo "$(GREEN)Connecting to Asus server...$(NC)"
	@SERVER_IP=$$(grep ansible_host $(INVENTORY) | head -1 | awk '{print $$2}' | cut -d'=' -f2); \
	SERVER_USER=$$(grep ansible_user $(INVENTORY) | head -1 | awk '{print $$2}' | cut -d'=' -f2); \
	ssh $$SERVER_USER@$$SERVER_IP

##@ Documentation

show-domains: ## Show all configured domains
	@echo "$(BLUE)Configured Domains:$(NC)"
	@echo ""
	@grep "_domain:" $(ANSIBLE_DIR)/group_vars/all.yml | grep -v "^#" | sed 's/^/  /'
	@echo ""
	@echo "$(YELLOW)Add these to your Mac's /etc/hosts:$(NC)"
	@SERVER_IP=$$(grep ansible_host $(INVENTORY) | head -1 | awk '{print $$2}'); \
	echo "$$SERVER_IP flow.local"; \
	echo "$$SERVER_IP api.flow.local"; \
	echo "$$SERVER_IP tradewhispr.local"; \
	echo "$$SERVER_IP api.tradewhispr.local"; \
	echo "$$SERVER_IP traefik.local"

hosts-file: ## Generate /etc/hosts entries for Mac
	@echo "$(BLUE)Copy these lines to /etc/hosts on your Mac:$(NC)"
	@echo ""
	@SERVER_IP=$$(grep ansible_host $(INVENTORY) | head -1 | awk '{print $$2}'); \
	echo "# Mini Server - Added by Ansible"; \
	echo "$$SERVER_IP flow.local"; \
	echo "$$SERVER_IP api.flow.local"; \
	echo "$$SERVER_IP tradewhispr.local"; \
	echo "$$SERVER_IP api.tradewhispr.local"; \
	echo "$$SERVER_IP traefik.local"
	@echo ""
	@echo "$(YELLOW)Run: sudo nano /etc/hosts$(NC)"

##@ Backup

backup-flow-db: ## Backup Flow database
	@echo "$(GREEN)Backing up Flow database...$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "docker exec flow-db pg_dump -U flowuser flowdb > /opt/backups/flow_$$(date +%Y%m%d_%H%M%S).sql" -b

backup-tradewhispr-db: ## Backup Tradewhispr database
	@echo "$(GREEN)Backing up Tradewhispr database...$(NC)"
	ansible mini_servers -i $(INVENTORY) -m shell -a "docker exec tradewhispr-db pg_dump -U tradewhispruser tradewhisprdb > /opt/backups/tradewhispr_$$(date +%Y%m%d_%H%M%S).sql" -b

backup-all: backup-flow-db backup-tradewhispr-db ## Backup all databases

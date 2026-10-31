SHELL := /bin/bash
COMPOSE := docker compose
PROD := $(COMPOSE) -f docker-compose.yml
DEV := $(COMPOSE) -f docker-compose.dev.yml

.DEFAULT_GOAL := help
.PHONY: help build up down restart ps logs shell auth run dev dev-down dev-logs \
        update backup backup-workspace restore health clean

help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'

build: ## Build the production image
	$(PROD) build

up: ## Start the production stack
	$(PROD) up -d --build

down: ## Stop the production stack (volumes are kept)
	$(PROD) down

restart: ## Restart the service
	$(PROD) restart opencode

ps: ## Show service status
	$(PROD) ps

logs: ## Follow the container logs
	$(PROD) logs -f --tail=100 opencode

shell: ## Open a bash shell in the container
	$(PROD) exec opencode bash

auth: ## Interactive provider login (persisted in the data volume)
	$(PROD) run --rm opencode auth login

run: ## Run a one-off prompt: make run PROMPT="explain this repo"
	$(PROD) run --rm opencode run "$(PROMPT)"

dev: ## Start the local development stack with bind mounts
	$(DEV) up -d --build

dev-down: ## Stop the local development stack
	$(DEV) down

dev-logs: ## Follow the local development logs
	$(DEV) logs -f --tail=100 opencode

update: ## Pull the newest base image and redeploy
	$(PROD) build --pull
	$(PROD) up -d

backup: ## Back up data and config to ./backups
	./scripts/backup.sh

backup-workspace: ## Back up data, config and /workspace
	WITH_WORKSPACE=1 ./scripts/backup.sh

restore: ## Restore a backup: make restore FILE=backups/x.tar.gz
	./scripts/restore.sh "$(FILE)"

health: ## Query the health endpoint from inside the container
	@$(PROD) exec opencode sh -c \
	  'curl -fsS -u "$$OPENCODE_SERVER_USERNAME:$$OPENCODE_SERVER_PASSWORD" http://127.0.0.1:4096/global/health' && echo

clean: ## Remove containers and local images
	$(PROD) down --rmi local

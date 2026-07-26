# SAIA Plugin - Makefile for common tasks
# Use: make <target>

.PHONY: help build test lint clean docker dockertest sandbox install uninstall

# Colors
GREEN := \033[0;32m
YELLOW := \033[1;33m
NC := \033[0m

HELP_TEXT = \
$(YELLOW)SAIA Plugin for pi Coding Agent - Makefile$(NC)

Usage: make <target>

Core Targets:
  help           Show this help message
  build          TypeScript type checking
  test           Run all tests
  lint           Run linter (eslint)
  clean          Remove build artifacts

Docker Targets:
  docker         Build Docker images
  docker-dev     Build development Docker image
  docker-push    Push Docker images to GHCR
  docker-pull    Pull Docker images from GHCR
  docker-run     Run sandbox container
  docker-shell   Start shell in sandbox container
  dockertest     Run tests in Docker sandbox

Sandbox Targets:
  sandbox        Start interactive sandbox
  sandbox-dev    Start development sandbox
  sandbox-test   Run sandbox tests

Installation Targets:
  install        Install plugin locally
  uninstall      Remove plugin installation

Example:
  make test
  make docker docker-push
  SAIA_API_KEY=your_key make sandbox


all: help

# =============================================================================
# Core Targets
# =============================================================================

help: ## Show this help message
	@echo "$(HELP_TEXT)"

build: ## TypeScript type checking
	@echo "$(GREEN)✓ Checking TypeScript types...$(NC)"
	npx tsc --noEmit --skipLibCheck

# test: ## Run all tests
# 	@echo "$(GREEN)✓ Running tests...$(NC)"
# 	bash test/test.sh

lint: ## Run linter
	@echo "$(GREEN)✓ Running ESLint...$(NC)"
	npx eslint src/ --ext .ts 2>/dev/null || echo "ESLint not installed. Run: npm install eslint --save-dev"

clean: ## Remove build artifacts
	@echo "$(GREEN)✓ Cleaning build artifacts...$(NC)"
	rm -rf node_modules/.cache
	rm -rf .nyc_output
	rm -rf coverage
	rm -rf dist
	rm -f *.tsbuildinfo
	find src -name "*.js.map" -delete
	find src -name "*.js" -delete

# =============================================================================
# Docker Targets
# =============================================================================

DOCKER_IMAGE := ghcr.io/graphwiz-ai/pi-saia-plugin
DOCKER_TAG := latest
DOCKER_TAG_DEV := latest-dev

docker: ## Build Docker images
	@echo "$(GREEN)✓ Building production Docker image...$(NC)"
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG) .

	@echo "$(GREEN)✓ Building development Docker image...$(NC)"
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG_DEV) --target builder .

docker-dev: ## Build development Docker image only
	@echo "$(GREEN)✓ Building development Docker image...$(NC)"
	docker build -t $(DOCKER_IMAGE):$(DOCKER_TAG_DEV) --target builder .

docker-push: ## Push Docker images to GHCR
	@echo "$(GREEN)✓ Pushing production Docker image...$(NC)"
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG)

	@echo "$(GREEN)✓ Pushing development Docker image...$(NC)"
	docker push $(DOCKER_IMAGE):$(DOCKER_TAG_DEV)

docker-pull: ## Pull Docker images from GHCR
	@echo "$(GREEN)✓ Pulling production Docker image...$(NC)"
	docker pull $(DOCKER_IMAGE):$(DOCKER_TAG)

	@echo "$(GREEN)✓ Pulling development Docker image...$(NC)"
	docker pull $(DOCKER_IMAGE):$(DOCKER_TAG_DEV)

docker-run: ## Run sandbox container
	@echo "$(GREEN)✓ Running sandbox container...$(NC)"
	docker run -it --rm \
		-e SAIA_API_KEY="$(SAIA_API_KEY)" \
		-e SAIA_PROFILE="$(SAIA_PROFILE:-production)" \
		-v $(CURDIR):/workspace \
		-w /workspace \
		$(DOCKER_IMAGE):$(DOCKER_TAG) sh

docker-shell: ## Start shell in sandbox container
	@echo "$(GREEN)✓ Starting shell in sandbox container...$(NC)"
	docker run -it --rm \
		-e SAIA_API_KEY="$(SAIA_API_KEY)" \
		-e SAIA_PROFILE="$(SAIA_PROFILE:-development)" \
		-v $(CURDIR):/home/pluginuser/app \
		-w /home/pluginuser/app \
		$(DOCKER_IMAGE):$(DOCKER_TAG_DEV) sh

dockertest: ## Run tests in Docker sandbox
	@echo "$(GREEN)✓ Running tests in Docker sandbox...$(NC)"
	docker run --rm \
		-e SAIA_API_KEY="mock-test-key" \
		-e SAIA_PROFILE="budget" \
		-v $(CURDIR):/home/pluginuser/app:ro \
		$(DOCKER_IMAGE):$(DOCKER_TAG) \
		bash -c "cd /home/pluginuser/app && bash test/test.sh"

# =============================================================================
# Sandbox Targets
# =============================================================================

sandbox: ## Start interactive sandbox
	@echo "$(GREEN)✓ Starting interactive sandbox...$(NC)"
	./sandbox/run.sh

sandbox-dev: ## Start development sandbox
	@echo "$(GREEN)✓ Starting development sandbox...$(NC)"
	./sandbox/dev.sh

sandbox-test: ## Run sandbox tests
	@echo "$(GREEN)✓ Running sandbox tests...$(NC)"
	./sandbox/test.sh

sandbox-showcase: ## Run showcase mode (ASCII art, stories, etc.)
	@echo "$(GREEN)✓ Running showcase mode...$(NC)"
	./sandbox/showcase.sh

sandbox-ascii: ## Show ASCII art showcase
	@echo "$(GREEN)✓ Running ASCII showcase...$(NC)"
	./sandbox/showcase.sh ascii

sandbox-story: ## Show story showcase
	@echo "$(GREEN)✓ Running story showcase...$(NC)"
	./sandbox/showcase.sh story

sandbox-joke: ## Tell a programming joke
	@echo "$(GREEN)✓ Running joke showcase...$(NC)"
	./sandbox/showcase.sh joke

# =============================================================================
# Installation Targets
# =============================================================================

PLUGIN_DIR := ~/.config/pi/plugins/saia

install: ## Install plugin locally
	@echo "$(GREEN)✓ Installing SAIA plugin...$(NC)"
	mkdir -p $(PLUGIN_DIR)
	cp -r src/* schema/* $(PLUGIN_DIR)/
	chmod +x $(PLUGIN_DIR)/*.sh
	cp pi.json.example ~/.config/pi/pi.json
	echo "Plugin installed to $(PLUGIN_DIR)"
	echo " Configure your API key: export SAIA_API_KEY=your_key"

uninstall: ## Remove plugin installation
	@echo "$(GREEN)✓ Removing SAIA plugin...$(NC)"
	rm -rf $(PLUGIN_DIR)
	echo "Plugin removed from $(PLUGIN_DIR)"

# =============================================================================
# Utility Targets
# =============================================================================

.PHONY: docker-buildx docker-validate docker-clean

docker-buildx: ## Build multi-arch Docker images
	@echo "$(GREEN)✓ Building multi-architecture Docker images...$(NC)"
	docker buildx create --use 2>/dev/null || true
	docker buildx build --platform linux/amd64,linux/arm64 \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG) \
		-t $(DOCKER_IMAGE):$(DOCKER_TAG_DEV) --target builder \
		--push .

docker-validate: ## Validate Dockerfile
	@echo "$(GREEN)✓ Validating Dockerfile...$(NC)"
	docker build --dry-run .

docker-clean: ## Clean Docker artifacts
	@echo "$(GREEN)✓ Cleaning Docker artifacts...$(NC)"
	docker image prune -a
	docker builder prune
	docker system prune -f

# =============================================================================
# Version Targets
# =============================================================================

.PHONY: version bump-major bump-minor bump-patch

version: ## Show current version
	@echo "$(GREEN)✓ Current version:$(NC) $(shell cat package.json | jq -r '.version')"

bump-major: ## Bump major version
	@echo "$(GREEN)✓ Bumping major version...$(NC)"
	npm version major -m "Bump major version"

bump-minor: ## Bump minor version
	@echo "$(GREEN)✓ Bumping minor version...$(NC)"
	npm version minor -m "Bump minor version"

bump-patch: ## Bump patch version
	@echo "$(GREEN)✓ Bumping patch version...$(NC)"
	npm version patch -m "Bump patch version"

# =============================================================================
# Help text for specific categories
# =============================================================================

help-%:
	@echo "Available '$*' targets:"
	@grep -E "^$*:" Makefile | grep -v " help-$*" | sed 's/:.*## /: /' | column -t -s ':' | sed 's/^  */  /'
	@echo ""

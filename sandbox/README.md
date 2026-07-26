# SAIA Plugin Sandbox Environment

This directory contains configuration and scripts for running the SAIA plugin in an isolated Docker sandbox environment. This is useful for:

- **Testing** the plugin without affecting your local setup
- **Development** with all dependencies pre-installed
- **CI/CD** pipelines
- **Tutorials and demos**

## Quick Start

### 1. Build the Docker Image

```bash
# From the project root
docker build -t ghcr.io/graphwiz-ai/pi-saia-plugin:latest .

# Or pull the pre-built image
docker pull ghcr.io/graphwiz-ai/pi-saia-plugin:latest
```

### 2. Run the Sandbox

```bash
# Basic sandbox with your API key
docker run -it --rm \
  -e SAIA_API_KEY="your_actual_api_key" \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest sh

# With development profile
docker run -it --rm \
  -e SAIA_API_KEY="your_actual_api_key" \
  -e SAIA_PROFILE="development" \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest sh

# With volume mount for config persistence
docker run -it --rm \
  -e SAIA_API_KEY="your_actual_api_key" \
  -v $(pwd)/pi-config:/home/pluginuser/.config/pi \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest sh
```

### 3. Run the Showcase

```bash
# Show ASCII art (works without API key)
docker run -it --rm \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest \
  bash /home/pluginuser/app/sandbox/showcase.sh ascii

# Generate content with pi (requires API key)
docker run -it --rm \
  -e SAIA_API_KEY="your_actual_api_key" \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest \
  bash /home/pluginuser/app/sandbox/showcase.sh story
```

### 4. Run Specific Tests

```bash
# Run TypeScript compilation check
docker run -it --rm \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest \
  npx tsc --noEmit --skipLibCheck

# Validate JSON files
docker run -it --rm \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest \
  jq empty package.json tsconfig.json

# Run the full test suite
docker run -it --rm \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest \
  bash test/test.sh
```

## Available Images

| Image Tag | Description | Size |
|-----------|-------------|------|
| `latest` | Production-ready image with all runtime dependencies | ~50MB |
| `X.Y.Z` | Version-specific production image | ~50MB |
| `latest-dev` | Development image with all build tools | ~200MB |

## Sandbox Features

### Pre-installed Tools

- **Node.js** 24.x
- **NPM** with all project dependencies
- **curl** and **jq** for API interactions
- **bash**, **git**, **bc** for scripting
- **TypeScript** for development

### Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SAIA_API_KEY` | Yes | - | Your GWDG Chat AI API key |
| `SAIA_PROFILE` | No | `production` | Model profile: production, development, budget |
| `LITELLM_PROXY_URL` | No | - | Optional LiteLLM proxy URL |
| `NODE_ENV` | No | `production` | Node.js environment mode |

### Volume Mounts

| Mount Point | Purpose |
|-------------|---------|
| `/home/pluginuser/.config/pi` | Persistent pi configuration |
| `/home pluginuser/.cache/saia` | Model cache and usage tracking |
| `/home/pluginuser/app` | Plugin source files |

## Usage Examples

### Example 1: Generate Configuration

```bash
docker run -it --rm \
  -e SAIA_API_KEY="your_api_key" \
  -e SAIA_PROFILE="production" \
  -v $(pwd):/workspace \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest \
  bash -c "cd /home/pluginuser/app && ./src/generate-saia-config.sh"
```

### Example 2: Development Shell

```bash
docker run -it --rm \
  -e SAIA_API_KEY="your_api_key" \
  -v $(pwd):/home/pluginuser/app \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest-dev \
  bash
```

### Example 3: API Validation

```bash
docker run -it --rm \
  -e SAIA_API_KEY="your_api_key" \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest \
  bash -c "curl -s -H 'Authorization: Bearer \$SAIA_API_KEY' \
    https://chat-ai.academiccloud.de/v1/models | jq '.data | length'"
```

### Example 4: Run the Setup Wizard

```bash
docker run -it --rm \
  -e SAIA_API_KEY="your_api_key" \
  -v $(pwd)/pi-config:/home/pluginuser/.config/pi \
  ghcr.io/graphwiz-ai/pi-saia-plugin:latest \
  bash /home/pluginuser/app/src/setup-wizard.sh
```

## Sandbox Scripts

### `sandbox/run.sh` - Quick Sandbox Launcher

```bash
# Start a pre-configured sandbox
./sandbox/run.sh

# With custom API key
SAIA_API_KEY="your_key" ./sandbox/run.sh

# With custom profile
SAIA_PROFILE="budget" ./sandbox/run.sh
```

### `sandbox/test.sh` - Run Tests in Sandbox

```bash
# Run all tests
./sandbox/test.sh

# Run specific test
./sandbox/test.sh typescript
./sandbox/test.sh shell
./sandbox/test.sh json
```

### `sandbox/dev.sh` - Development Environment

```bash
# Start development container with volume mount
./sandbox/dev.sh
```

## Docker Compose

For more complex setups, use Docker Compose:

```yaml
# docker-compose.yml
version: '3.8'
services:
  saia-plugin:
    image: ghcr.io/graphwiz-ai/pi-saia-plugin:latest
    environment:
      - SAIA_API_KEY=${SAIA_API_KEY}
      - SAIA_PROFILE=development
    volumes:
      - ./pi-config:/home/pluginuser/.config/pi
      - ./app:/home/pluginuser/app
    stdin_open: true
    tty: true
```

Run with:
```bash
docker compose up -d
docker compose exec saia-plugin sh
```

## Building Locally

### Standard Build

```bash
docker build -t pi-saia-plugin .
```

### Multi-Architecture Build

```bash
docker buildx create --use
docker buildx build --platform linux/amd64,linux/arm64 \
  -t ghcr.io/graphwiz-ai/pi-saia-plugin:latest \
  --push .
```

### Development Build

```bash
docker build -t pi-saia-plugin-dev --target builder .
```

## Testing in Sandbox

The sandbox includes a comprehensive test suite:

```bash
# Run all tests
docker run --rm pi-saia-plugin bash test/test.sh

# Run specific test category
docker run --rm pi-saia-plugin bash -c "source test/test.sh; test_typescript"
```

## Cleanup

Remove unused images:
```bash
docker image prune -a
docker builder prune
```

Remove stopped containers:
```bash
docker container prune
```

## Security

- Runs as non-root user (`pluginuser`)
- Read-only filesystem option available
- Environment variables for sensitive data
- Regular security scans via Trivy

## Troubleshooting

| Issue | Solution |
|-------|----------|
| Permission denied | Use `-v $(pwd):/workspace` instead of bind mounts |
| API key not working | Ensure `SAIA_API_KEY` is set correctly |
| Docker build fails | Run `docker system prune` and retry |
| Container won't start | Check logs: `docker logs <container>` |

## Contributing

When contributing Docker-related changes:

1. Update the `Dockerfile` with your changes
2. Update this `README.md` with usage instructions
3. Update CI workflows if needed
4. Test locally before pushing:
   ```bash
   docker build -t test-image .
   docker run --rm test-image bash -c "your test commands"
   ```
5. Push to GitHub - the workflow will automatically build and push the image

## Related Files

- `Dockerfile` - Main Dockerfile with multi-stage builds
- `.dockerignore` - Files to exclude from Docker builds
- `.github/workflows/docker-build-push.yml` - CI/CD for Docker images
- `sandbox/run.sh` - Convenience script for running sandbox
- `sandbox/test.sh` - Sandbox test runner
- `sandbox/dev.sh` - Development environment launcher

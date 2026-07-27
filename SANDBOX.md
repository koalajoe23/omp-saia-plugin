# SAIA Plugin Sandbox Environment

The SAIA plugin now includes a **complete Docker-based sandbox environment** for isolated testing, development, and CI/CD integration. This allows you to test the plugin without affecting your local setup or requiring a full pi installation.

## 🚀 Quick Start

### Run the Sandbox

```bash
# Start an interactive sandbox shell
./sandbox/run.sh

# With your API key
SAIA_API_KEY=your_key_here ./sandbox/run.sh

# Development mode with live file editing
./sandbox/dev.sh

# Run tests in sandbox
./sandbox/test.sh
```

### Use Docker Commands

```bash
# Pull the latest image from GHCR
docker pull ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest

# Run a temporary container
docker run -it --rm \
  -e SAIA_API_KEY=your_key \
  ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest sh

# Build locally
docker build -t pi-saia-plugin .

# Use Make commands
make docker docker-push
make sandbox
```

## 📦 Available Images

| Image | Description | Size | Use Case |
|-------|-------------|------|----------|
| `ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest` | Production image | ~50MB | Runtime use, CI/CD |
| `ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest-dev` | Development image | ~200MB | Plugin development, testing |
| `ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:vX.Y.Z` | Versioned image | ~50MB | Specific release deployment |

## 🎯 Features

### ✅ Pre-configured Environment
- **Node.js 24.x** - Latest LTS version
- **All dependencies** - curl, jq, git, bash, bc, python3
- **Plugin files** - All source files pre-installed
- ** pi config structure** - Pre-configured directory layout

### ✅ Multiple Usage Modes

#### 1. Interactive Shell
```bash
./sandbox/run.sh
# or
docker run -it --rm ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest sh
```

#### 2. Development Mode
```bash
./sandbox/dev.sh
# Features:
# - Live file mounting from host
# - Persistent config and cache volumes
# - Port 8080 available for local testing
```

#### 3. Test Runner
```bash
./sandbox/test.sh
# Runs comprehensive tests:
# - TypeScript compilation
# - Shell script syntax
# - JSON validation
# - Filesystem checks
```

#### 4. Docker Compose
```bash
# Start all services
docker compose up

# Development mode
docker compose --profile dev up

# With mock API
docker compose --profile mock up
```

### ✅ Environment Variables

| Variable | Required | Default | Description |
|----------|----------|---------|-------------|
| `SAIA_API_KEY` | ❌ | - | Your GWDG Chat AI API key |
| `SAIA_PROFILE` | ❌ | `production` | Model profile (production, development, budget) |
| `LITELLM_PROXY_URL` | ❌ | - | Optional LiteLLM proxy URL |
| `NODE_ENV` | ❌ | `production` | Node.js environment mode |

### ✅ Volume Mounts

| Mount Point | Purpose | Persistence |
|-------------|---------|-------------|
| `/home/pluginuser/.config/pi` | pi configuration | Container (can be mapped) |
| `/home/pluginuser/.cache/saia` | Model cache & usage data | Container (can be mapped) |
| `/home/pluginuser/app` | Plugin source files | Read-only (mapped) |

## 🧪 Testing in Sandbox

The sandbox includes a comprehensive test suite:

```bash
# Run all tests
./sandbox/test.sh

# Run specific test category
./sandbox/test.sh typescript
./sandbox/test.sh shell
./sandbox/test.sh json
./sandbox/test.sh filesystem
```

### Test Categories

| Test | Description | Duration |
|------|-------------|----------|
| **Docker Image** | Verify image exists and is valid | 1s |
| **Container Basics** | Test container startup and config | 2s |
| **Dependencies** | Verify all tools are available | 3s |
| **Filesystem** | Check file structure and permissions | 2s |
| **TypeScript** | Type checking (dev image only) | 5s |
| **Shell Scripts** | Syntax validation | 2s |
| **JSON Validation** | Validate JSON files | 1s |

## 📁 File Structure

```
pi-saia-plugin/
├── sandbox/
│   ├── README.md          # Sandbox documentation
│   ├── run.sh             # Quick sandbox launcher
│   ├── dev.sh             # Development environment
│   ├── test.sh            # Sandbox test runner
│   └── docker-compose.yml # Docker Compose config
├── Dockerfile             # Multi-stage Docker build
├── .dockerignore          # Files to exclude from Docker builds
├── docker-compose.yml     # Docker Compose configuration
├── Makefile               # Common tasks and commands
└── .githooks/
    └── pre-push           # Pre-push validation
```

## 🔄 CI/CD Integration

The repository includes GitHub Actions workflows for automatic Docker builds:

### Workflow: `docker-build-push.yml`

```yaml
Trigger: push to main/master, tags, PRs
Jobs:
  1. Build and push production image
  2. Build and push development image
  3. Run sandbox tests
  4. Security vulnerability scan
```

### Available GitHub Actions Secrets

| Secret | Purpose | Required |
|--------|---------|----------|
| None | All images are public | ❌ |

**Note:** Docker images are built and pushed automatically on every commit to main.

## 📝 Usage Examples

### Example 1: Quick Test

```bash
# Test TypeScript compilation in sandbox
docker run --rm pi-saia-plugin npx tsc --noEmit --skipLibCheck
```

### Example 2: Generate Configuration

```bash
docker run --rm \
  -e SAIA_API_KEY=your_key \
  -e SAIA_PROFILE=production \
  pi-saia-plugin \
  bash src/generate-saia-config.sh
```

### Example 3: Development Session

```bash
# Start development container
./sandbox/dev.sh

# In the container:
cd /home/pluginuser/app
vim src/saia.ts  # Changes are live-mounted from host

# Test changes:
npx tsc --noEmit --skipLibCheck
```

### Example 4: CI/CD Pipeline

```yaml
# .github/workflows/ci.yml
name: CI
on: [push, pull_request]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      
      - name: Run sandbox tests
        run: |
          docker run --rm \
            ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest \
            bash /home/pluginuser/app/sandbox/test.sh
```

### Example 5: Run the Showcase Mode

```bash
# Show built-in ASCII art (works without API key)
docker run -it --rm \
  ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest \
  bash /home/pluginuser/app/sandbox/showcase.sh ascii

# Generate a story with pi (requires SAIA_API_KEY)
docker run -it --rm \
  -e SAIA_API_KEY="your_key" \
  ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest \
  bash /home/pluginuser/app/sandbox/showcase.sh story

# Tell a programming joke
docker run -it --rm \
  -e SAIA_API_KEY="your_key" \
  ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest \
  bash /home/pluginuser/app/sandbox/showcase.sh joke

# Custom prompt
SAIA_API_KEY=your_key ./sandbox/showcase.sh custom "Write a haiku about coding"
```

### Example 6: Local Mock API Testing

```bash
# Start mock API server
docker compose --profile mock up saia-mock-api

# In another terminal, test with mock API
docker run --rm \
  -e SAIA_API_KEY=mock-key \
  -e LITELLM_PROXY_URL=http://host.docker.internal:8080 \
  --network host \
  pi-saia-plugin \
  bash src/generate-saia-config.sh
```

## 🛡️ Security

### Container Security Features

- **Non-root user**: All containers run as `pluginuser` (UID 1000)
- **Read-only filesystem**: Option available for production
- **No sensitive data**: API keys are passed via environment variables
- **Regular scanning**: Trivy vulnerabilities scans on every release
- **Minimal base images**: Alpine Linux for small attack surface

### Security Scanning

```bash
# Run vulnerability scan
docker scan ghcr.io/tobias-weiss-ai-xr/pi-saia-plugin:latest

# View results in GitHub Security tab
# (automatically uploaded from CI)
```

## 🔧 Customization

### Build Custom Image

```bash
# Build with custom tag
docker build -t my-saia-plugin .

# Build for specific architecture
docker build --platform linux/arm64 -t saia-plugin-arm64 .

# Multi-architecture build
docker buildx build --platform linux/amd64,linux/arm64 \
  -t my-registry/saia-plugin:multiarch \
  --push .
```

### Custom Docker Compose

```yaml
# docker-compose.override.yml
version: '3.8'
services:
  saia-plugin-dev:
    volumes:
      - ./custom-config:/home/pluginuser/.config/pi
    environment:
      - SAIA_PROFILE=budget
    ports:
      - "8080:8080"
      - "3000:3000"
```

## 📊 Performance

| Operation | Time | Notes |
|-----------|------|-------|
| Image build | 2-3 minutes | Cached for subsequent builds |
| Container start | <2 seconds | Fast startup |
| TypeScript check | 5-10 seconds | Full project analysis |
| All sandbox tests | 30-60 seconds | Comprehensive validation |

## 🤝 Contributing

When contributing to the sandbox:

1. **Update documentation**: Keep `sandbox/README.md` up to date
2. **Test locally**: Run `./sandbox/test.sh` before committing
3. **Update CI**: Modify workflows if needed
4. **Tag images**: Version tags are automatically created from Git tags

### Adding New Features

```bash
# 1. Modify Dockerfile with new dependencies
vim Dockerfile

# 2. Update sandbox scripts if needed
vim sandbox/*.sh

# 3. Test locally
docker build -t test-image .
docker run --rm test-image ./sandbox/test.sh

# 4. Commit and push - CI will build and push images
```

## 🐛 Troubleshooting

### Common Issues

| Issue | Solution |
|-------|----------|
| `Permission denied` | Use `-v $(pwd):/workspace` or run as root |
| `API key not working` | Ensure `SAIA_API_KEY` is set correctly |
| `Docker build fails` | Run `docker system prune` and retry |
| `Container won't start` | Check logs: `docker logs <container>` |
| `Port already in use` | Use `--ports` flag or change port mapping |
| `Volume mount issues` | Ensure host directory exists |

### Debug Mode

```bash
# Run with debug output
docker run -it --rm \
  -e DEBUG=1 \
  pi-saia-plugin sh

# View Docker build logs
docker build --progress=plain --no-cache .
```

## 📚 Related Documentation

- [README.md](README.md) - Main plugin documentation
- [Dockerfile](Dockerfile) - Docker build configuration
- [.github/workflows/docker-build-push.yml](.github/workflows/docker-build-push.yml) - CI/CD workflow
- [sandbox/README.md](sandbox/README.md) - Sandbox-specific documentation

## 🎉 Next Steps

1. **Try the sandbox**: `./sandbox/run.sh`
2. **Explore commands**: `make help`
3. **Use in CI**: Check the workflow examples
4. **Contribute**: Add your own sandbox features

---

For questions or issues, please open an issue on [Codeberg](https://github.com/tobias-weiss-ai-xr/pi-saia-plugin/issues).

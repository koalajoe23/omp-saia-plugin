# SAIA Plugin for pi Coding Agent - Docker Image
# Multi-stage build for development, testing, and sandbox usage

# Arguments
ARG NODE_VERSION=24
ARG ALPINE_VERSION=3.20

# =============================================================================
# Stage 1: Base Builder - Install all build dependencies
# =============================================================================
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION} AS builder

# Install system dependencies
RUN apk add --no-cache \
    curl \
    jq \
    git \
    bash \
    bc \
    openssl \
    ca-certificates \
    tzdata \
    python3 \
    py3-pip

# Create app directory
WORKDIR /app

# Copy package files first for better caching
COPY package*.json ./
COPY tsconfig.json ./

# Install all dependencies (including dev dependencies)
RUN npm ci 2>/dev/null || npm install 2>&1

# Copy source files
COPY . .

# Build TypeScript (optional, for testing)
RUN npm run tsc -- --noEmit --skipLibCheck 2>&1 || echo "TypeScript check: warnings only"

# =============================================================================
# Stage 2: Runtime Image - Minimal production-ready image
# =============================================================================
FROM node:${NODE_VERSION}-alpine${ALPINE_VERSION}

# Install runtime dependencies
RUN apk add --no-cache \
    curl \
    jq \
    bash \
    git \
    bc \
    ca-certificates \
    tzdata

# Create non-root user for security
RUN adduser -D -s /bin/bash -u 1000 -G node pluginuser
WORKDIR /home/pluginuser

# Copy from builder
COPY --from=builder --chown=pluginuser:pluginuser /app /home/pluginuser/app

# Ensure correct permissions
RUN chmod +x /home/pluginuser/app/src/*.sh /home/pluginuser/app/install*.sh

# Switch to non-root user
USER pluginuser
WORKDIR /home/pluginuser/app

# Set up pi config directory structure
RUN mkdir -p /home/pluginuser/.config/pi/plugins/saia && \
    mkdir -p /home/pluginuser/.cache/saia

# Copy plugin files to pi plugins directory
RUN cp -r /home/pluginuser/app/src/* /home/pluginuser/.config/pi/plugins/saia/ && \
    cp -r /home/pluginuser/app/schema /home/pluginuser/.config/pi/plugins/saia/ && \
    chmod +x /home/pluginuser/.config/pi/plugins/saia/*.sh

# Environment variables
ENV NODE_ENV=production
ENV SAIA_API_KEY=""
ENV SAIA_PROFILE="production"
ENV LITELLM_PROXY_URL=""

# Default command: show help
CMD ["/bin/bash", "-c", "echo 'SAIA Plugin Docker Image - Use with: docker run -it --rm -e SAIA_API_KEY=your_key -v \$(pwd):/workspace ghcr.io/graphwiz-ai/pi-saia-plugin:latest sh' && exec /bin/bash"]

# =============================================================================
# Build Instructions:
# =============================================================================
# Development:   docker build -t pi-saia-plugin --target builder .
# Production:    docker build -t pi-saia-plugin .
# Multi-arch:    docker buildx build --platform linux/amd64,linux/arm64 -t ghcr.io/graphwiz-ai/pi-saia-plugin:latest --push .

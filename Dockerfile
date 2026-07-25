# Dockerfile for pi-saia-plugin
# Multi-stage build for smaller final image

# Stage 1: Build
FROM node:20-alpine AS builder

WORKDIR /app

# Copy package files
COPY package*.json ./

# Install dependencies
RUN npm ci --only=production

# Copy source files
COPY src/ ./src/
COPY schema/ ./schema/
COPY .opencode/ ./.opencode/
COPY install.sh install.ps1 prepare-release.sh ./
COPY pi.json.example ./

# Stage 2: Runtime
FROM node:20-alpine

WORKDIR /app

# Copy from builder
COPY --from=builder /app/ ./

# Create non-root user for security
RUN addgroup -S pi-saia && adduser -S pi-saia -G pi-saia
USER pi-saia

# Set environment variables
ENV NODE_ENV=production
ENV SAIA_PROFILE=production

# Expose port (if running a server, optional)
EXPOSE 3000

# Set entrypoint
ENTRYPOINT ["node"]
CMD ["src/saia.ts"]

# Alternative: Run the generation script
# CMD ["bash", "src/generate-saia-config.sh"]

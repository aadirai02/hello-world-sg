# --- Stage 1: Build Stage ---
# Use a specific version tag for reproducibility, never 'latest'
FROM node:18-alpine AS builder

# Set working directory
WORKDIR /app

# Copy package files first to leverage Docker cache for dependencies
COPY package*.json ./

# Install ONLY production dependencies
# 'npm ci' is faster and strictly adheres to package-lock.json
RUN npm ci --only=production

# --- Stage 2: Production Stage ---
# Start fresh with a clean, minimal image
FROM node:18-alpine

# Set working directory
WORKDIR /app

# Create a non-root user and group for security
# (Alpine node images come with a 'node' user, but explicit setting is safer)
USER node

# Copy built node_modules and application code from the builder stage
COPY --from=builder --chown=node:node /app/node_modules ./node_modules
COPY --chown=node:node . .

# Expose the port the app runs on
EXPOSE 3000

# Define environment variables with defaults (can be overridden by K8s ConfigMaps)
ENV NODE_ENV=production
ENV PORT=3000

# Start the application
CMD ["node", "server.js"]
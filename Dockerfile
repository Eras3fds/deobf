# Multi-stage build for minimal image
FROM alpine:latest AS builder

# Install build dependencies
RUN apk add --no-cache \
    build-base \
    cmake \
    git \
    curl \
    readline-dev

# Build LuaJIT 2.1 (latest stable)
WORKDIR /tmp
RUN git clone https://github.com/LuaJIT/LuaJIT.git && \
    cd LuaJIT && \
    git checkout v2.1 && \
    make -j$(nproc) && \
    make install PREFIX=/usr/local

# --- Main image ---
FROM node:20-alpine

# Install LuaJIT runtime dependencies
RUN apk add --no-cache \
    luajit \
    luajit-dev \
    readline \
    readline-dev \
    libgcc

# Copy LuaJIT from builder
COPY --from=builder /usr/local/lib/libluajit-5.1.so.2 /usr/lib/
COPY --from=builder /usr/local/bin/luajit /usr/bin/
COPY --from=builder /usr/local/include/luajit-2.1 /usr/include/luajit-2.1

# Create app directory
WORKDIR /app

# Copy package files
COPY package*.json ./

# Install Node.js dependencies
RUN npm ci --only=production

# Copy application files
COPY cli.lua ./server.js ./

# Create temp directory
RUN mkdir -p /tmp/prometheus-deob && chmod 777 /tmp/prometheus-deob

# Health check
HEALTHCHECK --interval=30s --timeout=10s --start-period=5s \
    CMD node -e "require('http').get('http://localhost:10000/health', (r) => process.exit(r.statusCode === 200 ? 0 : 1))"

# Expose port for Render
EXPOSE 10000

# Start bot
CMD ["node", "server.js"]

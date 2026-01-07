# Use LuaJIT for maximum performance
FROM alpine:3.18 AS builder

# Install build dependencies
RUN apk add --no-cache \
    luajit \
    luajit-dev \
    build-base \
    git \
    curl \
    tar \
    gzip

# Install LPM (Lit Package Manager)
WORKDIR /app
RUN curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh

# Copy dependency lock file
COPY package.json .

# Install dependencies (cached layer)
RUN ./lit install

# Final stage
FROM alpine:3.18

# Install runtime dependencies only
RUN apk add --no-cache \
    luajit \
    ca-certificates \
    libgcc

# Copy binaries and app
COPY --from=builder /app /app
COPY --from=builder /usr/bin/luajit /usr/bin/luajit
COPY --from=builder /usr/lib/libluajit*.so* /usr/lib/

WORKDIR /app

# Copy source code
COPY bot.lua .

# Create non-root user
RUN addgroup -g 1000 bot && \
    adduser -D -u 1000 -G bot bot && \
    chown -R bot:bot /app
USER bot

# Health check
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD luajit -e "require('http').get('http://localhost:10000', function() end)"

# Expose port for health check
EXPOSE 10000

# Start bot
CMD ["luajit", "bot.lua"]

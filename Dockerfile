FROM debian:bullseye-slim AS builder

# Install build dependencies
RUN apt-get update && apt-get install -y \
    luajit \
    libluajit-5.1-dev \
    build-essential \
    git \
    curl \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Install Lit (this downloads glibc-linked luvi binary)
RUN curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh

# Copy and install dependencies
COPY package.json .
RUN ./lit install

# Final stage
FROM debian:bullseye-slim

# Install runtime dependencies only
RUN apt-get update && apt-get install -y \
    luajit \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

COPY --from=builder /app /app
WORKDIR /app
COPY bot.lua .

# Create non-root user
RUN useradd -m -u 1000 bot && \
    chown -R bot:bot /app
USER bot

# Health check for Render
HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD luajit -e "require('http').get('http://localhost:10000', function() end)" || exit 1

EXPOSE 10000
CMD ["luajit", "bot.lua"]

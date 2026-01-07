FROM alpine:3.18 AS builder

# Add glibc compatibility layer for luvi binary
RUN apk add --no-cache \
    luajit \
    luajit-dev \
    build-base \
    git \
    curl \
    tar \
    gzip \
    libc6-compat  # FIX: Allows running glibc-compiled binaries

WORKDIR /app

# Install LIT (with execute permissions fix)
RUN curl -L https://github.com/luvit/lit/raw/master/get-lit.sh | sh && \
    chmod +x luvi lit  # FIX: Ensure binaries are executable

COPY package.json .
RUN ./lit install

FROM alpine:3.18

RUN apk add --no-cache \
    luajit \
    ca-certificates \
    libgcc \
    libc6-compat  # FIX: Also needed in runtime image

COPY --from=builder /app /app
COPY --from=builder /usr/bin/luajit /usr/bin/luajit
COPY --from=builder /usr/lib/libluajit*.so* /usr/lib/

WORKDIR /app
COPY bot.lua .

RUN addgroup -g 1000 bot && \
    adduser -D -u 1000 -G bot bot && \
    chown -R bot:bot /app
USER bot

HEALTHCHECK --interval=30s --timeout=5s --start-period=10s --retries=3 \
    CMD luajit -e "require('http').get('http://localhost:10000', function() end)"

EXPOSE 10000
CMD ["luajit", "bot.lua"]

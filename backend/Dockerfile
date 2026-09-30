# syntax=docker/dockerfile:1

# ---- Build: static binary on Alpine (musl) ----
ARG CRYSTAL_VERSION=1.21.1
FROM crystallang/crystal:${CRYSTAL_VERSION}-alpine AS build
RUN apk add --no-cache sqlite-dev sqlite-static
WORKDIR /src

COPY shard.yml shard.lock* ./
RUN shards install --skip-postinstall

COPY src ./src
COPY db ./db
RUN mkdir -p bin && crystal build src/app.cr -o bin/urlku --release --static --no-debug

# ---- Runtime ----
FROM alpine:3.20
RUN addgroup -S urlku && adduser -S -G urlku urlku \
    && mkdir -p /app/data && chown urlku:urlku /app/data
WORKDIR /app
COPY --from=build /src/bin/urlku /app/urlku

ENV PORT=3000 \
    HOST=0.0.0.0 \
    DATABASE_URL=/app/data/urlku.db \
    KEMAL_ENV=production

USER urlku
EXPOSE 3000
VOLUME ["/app/data"]
HEALTHCHECK --interval=30s --timeout=3s --start-period=5s \
  CMD wget -qO- "http://127.0.0.1:${PORT}/health" >/dev/null || exit 1

CMD ["/app/urlku"]

# syntax=docker/dockerfile:1

# ---------- 阶段一：构建前端 ----------
FROM node:22-alpine AS web-builder
WORKDIR /app

RUN corepack enable \
    && corepack prepare pnpm@11.15.1 --activate

ENV npm_config_fetch_retries=5 \
    npm_config_fetch_retry_wait=2000 \
    npm_config_fetch_timeout=600000 \
    npm_config_network_timeout=600000 \
    pnpm_config_fetch_retries=5 \
    pnpm_config_fetch_retry_wait=2000 \
    pnpm_config_fetch_timeout=600000

COPY web ./web
RUN cd web && pnpm install --frozen-lockfile --prefer-offline
RUN pnpm --dir web build

# ---------- 阶段二：编译 Go 后端 ----------
FROM golang:1.26.9 AS go-builder
WORKDIR /app
ARG TARGETOS
ARG TARGETARCH

COPY go.mod go.sum ./
COPY agent ./agent
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=${TARGETOS:-linux} GOARCH=${TARGETARCH:-amd64} go build -o /denova ./cmd/denova

# ---------- 阶段三：最小化运行镜像 ----------
FROM alpine:3.20
RUN apk add --no-cache bash ca-certificates ripgrep

WORKDIR /app

COPY --from=go-builder /denova /app/denova
COPY --from=web-builder /app/web/dist /app/web/dist

EXPOSE 7788 7789

CMD ["/app/denova"]

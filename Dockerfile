# syntax=docker/dockerfile:1

# ---------- 阶段一：构建前端 ----------
FROM node:22-alpine AS web-builder
WORKDIR /app

RUN corepack enable

COPY web ./web
RUN cd web && pnpm install --frozen-lockfile
RUN pnpm --dir web build

# ---------- 阶段二：编译 Go 后端 ----------
FROM golang:1.26.9 AS go-builder
WORKDIR /app

COPY go.mod go.sum ./
COPY agent ./agent
RUN go mod download

COPY . .
RUN CGO_ENABLED=0 GOOS=linux GOARCH=amd64 go build -o /denova ./cmd/denova

# ---------- 阶段三：最小化运行镜像 ----------
FROM alpine:3.20
RUN apk add --no-cache bash ca-certificates ripgrep

WORKDIR /app

COPY --from=go-builder /denova /app/denova
COPY --from=web-builder /app/web/dist /app/web/dist

EXPOSE 7788 7789

CMD ["/app/denova"]

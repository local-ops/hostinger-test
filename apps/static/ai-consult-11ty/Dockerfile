# syntax=docker/dockerfile:1
FROM node:lts-alpine AS builder
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci
COPY eleventy.config.js ./
COPY src ./src
RUN npm run build

FROM nginx:alpine
COPY --from=builder /app/_site /usr/share/nginx/html

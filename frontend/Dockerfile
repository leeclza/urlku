# syntax=docker/dockerfile:1

# ---- Build static assets ----
FROM node:22-alpine AS build
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --no-audit --no-fund
COPY . .

# Vite inlines these at build time.
ARG VITE_API_URL=http://localhost:3000
ARG VITE_BASE_URL=http://localhost:3000
ENV VITE_API_URL=$VITE_API_URL \
    VITE_BASE_URL=$VITE_BASE_URL
RUN npm run build

# ---- Serve with nginx ----
FROM nginx:1.27-alpine
COPY nginx.conf /etc/nginx/conf.d/default.conf
COPY --from=build /app/dist /usr/share/nginx/html
EXPOSE 80

# ── Base Image ──
FROM node:18-alpine AS base
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma/

# ── Dependencies ──
FROM base AS dependencies
RUN npm ci
RUN npx prisma generate

# ── Build ──
FROM base AS build
COPY --from=dependencies /app/node_modules ./node_modules
COPY . .
RUN npm run build
# Prune devDependencies to keep image small
RUN npm prune --production

# ── Production Image ──
FROM node:18-alpine AS production
WORKDIR /app
# Only copy necessary artifacts
COPY --from=build /app/dist ./dist
COPY --from=build /app/node_modules ./node_modules
COPY --from=build /app/package.json ./
COPY --from=build /app/prisma ./prisma

# Add entrypoint script to run Prisma migrations then start Fastify
RUN echo "#!/bin/sh" > /app/entrypoint.sh \
  && echo "npx prisma migrate deploy" >> /app/entrypoint.sh \
  && echo "node dist/index.js" >> /app/entrypoint.sh \
  && chmod +x /app/entrypoint.sh

ENV NODE_ENV=production
EXPOSE 8080

ENTRYPOINT ["/app/entrypoint.sh"]

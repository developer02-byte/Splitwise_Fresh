# ── Base Image ──
FROM node:22-alpine AS base
RUN apk add --no-cache openssl
WORKDIR /app
COPY package*.json ./
COPY prisma ./prisma/

# ── Dependencies ──
FROM base AS dependencies
RUN npm install --omit=optional
RUN npx prisma generate

# ── Production Image ──
FROM node:22-alpine AS production
RUN apk add --no-cache openssl
WORKDIR /app

COPY --from=dependencies /app/node_modules ./node_modules
COPY . .

# Re-run prisma generate in production context
RUN npx prisma generate

ENV NODE_ENV=production
EXPOSE 3000

CMD ["sh", "-c", "npx prisma db push --skip-generate && npx tsx src/index.ts"]

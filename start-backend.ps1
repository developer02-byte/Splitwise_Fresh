# Start Database
Write-Host "Starting Database Containers..." -ForegroundColor Cyan
docker-compose up -d postgres redis

# Wait a moment for Postgres to boot
Start-Sleep -Seconds 3

# Setup DB and Start Fastify Backend
cd backend
Write-Host "Updating Database Schema..." -ForegroundColor Cyan
npx prisma db push

Write-Host "Starting Node.js API..." -ForegroundColor Green
npx tsx src/index.ts

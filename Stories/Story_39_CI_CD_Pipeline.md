# Story 33: CI/CD Pipeline - Detailed Execution Plan

## 1. Core Objective & Philosophy
Automated testing and deployment pipeline using a self-hosted runner. Every push is tested. Every merge to main is deployable. The pipeline is the single gatekeeper — no code reaches production without passing lint, test, and build stages. Manual deployments are eliminated entirely.

---

## 2. Target Persona & Motivation
- **The Solo Developer:** Wants confidence that every push is validated automatically, catching regressions before they reach production.
- **The Future Team Member:** Needs a clear, reproducible pipeline that works identically for every contributor without local environment quirks.
- **The On-Call Deployer:** Wants merge-to-main to mean "deployed in minutes" with automatic rollback if something breaks.

---

## 3. Comprehensive Step-by-Step Journey

### A. Self-Hosted Runner Setup
1. **Initial setup:** GitHub Actions self-hosted runner installed on the same development machine during local dev phase.
2. **Runner registration:** Runner registered to the GitHub repository via `./config.sh --url https://github.com/<owner>/<repo> --token <TOKEN>`.
3. **Runner service:** Runner configured as a background service (`svc.sh install && svc.sh start`) so it survives reboots.
4. **Migration to Hetzner:** When the project moves to Hetzner VPS, the runner is re-provisioned on the server. The workflow files remain unchanged — only the runner machine changes.
5. **Runner labels:** Runner tagged with `self-hosted, linux, x64` for workflow targeting.

### B. Pipeline Stages

#### Stage 1: Lint
- **Backend:** ESLint runs against all backend TypeScript/JavaScript files.
  - Config: `.eslintrc.js` with strict rules (no-unused-vars, no-any, consistent-return).
  - Command: `npx eslint src/ --max-warnings 0` (zero warnings policy).
- **Frontend:** Flutter analyze runs against all Dart files.
  - Command: `flutter analyze --no-pub` (assumes dependencies cached).
  - Any info/warning/error fails the pipeline.

#### Stage 2: Test
- **Backend:** Vitest runs all backend unit and integration tests.
  - Test database: Dedicated PostgreSQL instance (Docker container) spun up per CI run.
  - Test Redis: Dedicated Redis container spun up per CI run.
  - Command: `npx vitest run --coverage` (no watch mode in CI).
  - Coverage threshold enforced: minimum 80% line coverage.
  - Environment: `.env.test` with `DATABASE_URL` pointing to CI test database.
  - Before tests: `npx prisma migrate deploy` runs against the test database.
- **Frontend:** Flutter test runs all widget and unit tests.
  - Command: `flutter test --coverage`.
  - Coverage report generated as `lcov.info`.

#### Stage 3: Build
- **Backend:** TypeScript compilation (if applicable) via `npm run build`.
  - Produces `dist/` directory with compiled JavaScript.
  - Build failure = pipeline failure.
- **Frontend (Web):** `flutter build web --release` produces optimized web assets.
- **Frontend (Android):** `flutter build apk --release` produces APK.
  - Signing key stored as GitHub secret (`ANDROID_KEYSTORE_BASE64`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD`).
  - Keystore decoded from base64 during CI run.
- **Frontend (iOS):** Deferred — requires macOS runner for Xcode builds. Added when publishing to App Store.

#### Stage 4: Deploy (main branch only)
1. **Docker build:** Multi-stage Dockerfile builds production images for backend and frontend.
2. **Push to registry:** Images pushed to GitHub Container Registry (`ghcr.io/<owner>/<repo>`).
3. **SSH deploy:** CI SSHs into Hetzner VPS and runs:
   ```bash
   docker-compose pull
   docker-compose up -d --remove-orphans
   ```
4. **Health check:** After deploy, CI waits 15 seconds then hits `GET /api/health`.
   - Success (HTTP 200 with `{ "status": "ok", "db": "connected", "redis": "connected" }`): deploy complete.
   - Failure (non-200 or timeout): automatic rollback to previous image tag.
5. **Rollback procedure:**
   ```bash
   docker-compose down
   docker tag ghcr.io/<owner>/<repo>/backend:previous ghcr.io/<owner>/<repo>/backend:latest
   docker-compose up -d
   ```

### C. Trigger Rules
| Event | Branches | Stages |
| --- | --- | --- |
| Push | Any branch | Lint + Test |
| Pull Request to main | main | Lint + Test + Build |
| Merge to main | main | Lint + Test + Build + Deploy |

### D. Docker Build Strategy

#### Backend Multi-Stage Dockerfile
```dockerfile
# Stage 1: Build
FROM node:20-alpine AS builder
WORKDIR /app
COPY package*.json ./
RUN npm ci --only=production=false
COPY . .
RUN npm run build
RUN npm prune --production

# Stage 2: Production
FROM node:20-alpine
WORKDIR /app
COPY --from=builder /app/dist ./dist
COPY --from=builder /app/node_modules ./node_modules
COPY --from=builder /app/package.json ./
COPY --from=builder /app/prisma ./prisma
EXPOSE 3000
CMD ["node", "dist/server.js"]
```

#### Frontend (Flutter Web) Dockerfile
```dockerfile
FROM ghcr.io/cirruslabs/flutter:stable AS builder
WORKDIR /app
COPY . .
RUN flutter build web --release

FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
```

### E. Environment Secrets Management
- All secrets stored in GitHub repository Settings > Secrets and Variables > Actions.
- Secrets NEVER appear in workflow YAML files — only referenced as `${{ secrets.SECRET_NAME }}`.
- Required secrets:
  - `DATABASE_URL` — production PostgreSQL connection string
  - `JWT_SECRET` — token signing key
  - `REDIS_URL` — production Redis connection string
  - `HETZNER_SSH_KEY` — private SSH key for deploy
  - `HETZNER_HOST` — VPS IP address
  - `GHCR_TOKEN` — GitHub Container Registry push token
  - `ANDROID_KEYSTORE_BASE64` — Android signing keystore
  - `ANDROID_KEY_ALIAS` — keystore alias
  - `ANDROID_KEY_PASSWORD` — keystore password

### F. Mobile Build Pipeline
- **Android APK/AAB:**
  - Built in CI using the Flutter Docker image.
  - Signed with release keystore decoded from GitHub secret.
  - APK artifact uploaded via `actions/upload-artifact`.
  - AAB (Android App Bundle) built for Play Store submission.
- **iOS:**
  - Requires macOS runner (GitHub-hosted or self-hosted Mac).
  - Deferred until App Store submission phase.
  - Placeholder step in workflow that skips with a message.

### G. Notifications
- **Build failure:** GitHub webhook sends notification via email (configured in repository settings).
- **Optional Slack integration:** GitHub App for Slack posts to a `#deployments` channel on merge-to-main builds.
- **Failure notification includes:** commit SHA, branch, failing stage, link to logs.

---

## 4. Ultra-Detailed UI/UX Component Specifications
This story is infrastructure-only. No user-facing UI components. The pipeline operates entirely in GitHub Actions and the server environment.

**Developer-facing artifacts:**
- GitHub Actions workflow status badge in repository README.
- PR checks: green checkmark or red X on every pull request.
- Deployment status visible in GitHub Environments tab.

---

## 5. Technical Architecture & Configuration

### GitHub Actions Workflow File: `.github/workflows/ci.yml`
```yaml
name: CI/CD Pipeline

on:
  push:
    branches: ['*']
  pull_request:
    branches: [main]

jobs:
  lint:
    runs-on: self-hosted
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json
      - name: Backend Lint
        working-directory: backend
        run: |
          npm ci
          npx eslint src/ --max-warnings 0
      - name: Frontend Lint
        working-directory: frontend
        run: flutter analyze --no-pub

  test:
    runs-on: self-hosted
    needs: lint
    services:
      postgres:
        image: postgres:16
        env:
          POSTGRES_DB: splitwise_test
          POSTGRES_USER: test
          POSTGRES_PASSWORD: test
        ports:
          - 5433:5432
        options: >-
          --health-cmd pg_isready
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
      redis:
        image: redis:7
        ports:
          - 6380:6379
        options: >-
          --health-cmd "redis-cli ping"
          --health-interval 10s
          --health-timeout 5s
          --health-retries 5
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: 20
          cache: 'npm'
          cache-dependency-path: backend/package-lock.json
      - name: Backend Tests
        working-directory: backend
        env:
          DATABASE_URL: postgresql://test:test@localhost:5433/splitwise_test
          REDIS_URL: redis://localhost:6380
        run: |
          npm ci
          npx prisma migrate deploy
          npx vitest run --coverage
      - name: Frontend Tests
        working-directory: frontend
        run: flutter test --coverage

  build:
    runs-on: self-hosted
    needs: test
    if: github.event_name == 'pull_request' || (github.event_name == 'push' && github.ref == 'refs/heads/main')
    steps:
      - uses: actions/checkout@v4
      - name: Build Backend Docker Image
        run: docker build -t ghcr.io/${{ github.repository }}/backend:${{ github.sha }} ./backend
      - name: Build Frontend Web
        working-directory: frontend
        run: flutter build web --release
      - name: Build Android APK
        if: github.ref == 'refs/heads/main'
        working-directory: frontend
        run: |
          echo "${{ secrets.ANDROID_KEYSTORE_BASE64 }}" | base64 -d > android/app/keystore.jks
          flutter build apk --release
      - name: Upload APK Artifact
        if: github.ref == 'refs/heads/main'
        uses: actions/upload-artifact@v4
        with:
          name: app-release.apk
          path: frontend/build/app/outputs/flutter-apk/app-release.apk

  deploy:
    runs-on: self-hosted
    needs: build
    if: github.event_name == 'push' && github.ref == 'refs/heads/main'
    environment: production
    steps:
      - uses: actions/checkout@v4
      - name: Login to GHCR
        run: echo "${{ secrets.GHCR_TOKEN }}" | docker login ghcr.io -u ${{ github.actor }} --password-stdin
      - name: Push Docker Images
        run: |
          docker push ghcr.io/${{ github.repository }}/backend:${{ github.sha }}
          docker tag ghcr.io/${{ github.repository }}/backend:${{ github.sha }} ghcr.io/${{ github.repository }}/backend:latest
          docker push ghcr.io/${{ github.repository }}/backend:latest
      - name: Deploy to Hetzner
        env:
          SSH_KEY: ${{ secrets.HETZNER_SSH_KEY }}
          HOST: ${{ secrets.HETZNER_HOST }}
        run: |
          echo "$SSH_KEY" > /tmp/deploy_key && chmod 600 /tmp/deploy_key
          ssh -o StrictHostKeyChecking=no -i /tmp/deploy_key root@$HOST \
            "cd /opt/splitwise && docker-compose pull && docker-compose up -d --remove-orphans"
          rm /tmp/deploy_key
      - name: Health Check
        env:
          HOST: ${{ secrets.HETZNER_HOST }}
        run: |
          sleep 15
          STATUS=$(curl -s -o /dev/null -w "%{http_code}" http://$HOST:3000/api/health)
          if [ "$STATUS" != "200" ]; then
            echo "Health check failed with status $STATUS. Rolling back..."
            echo "${{ secrets.HETZNER_SSH_KEY }}" > /tmp/deploy_key && chmod 600 /tmp/deploy_key
            ssh -o StrictHostKeyChecking=no -i /tmp/deploy_key root@$HOST \
              "cd /opt/splitwise && docker-compose down && docker-compose up -d --remove-orphans"
            rm /tmp/deploy_key
            exit 1
          fi
          echo "Health check passed."
```

---

## 6. Comprehensive Edge Cases & QA

| Trigger Scenario | System Behavior | Resolution |
| --- | --- | --- |
| **Flaky test blocks deploy** | A test intermittently fails on CI but passes locally. | Investigate and fix the flaky test. Do NOT add retry logic — flaky tests mask real bugs. Quarantine the test if needed while investigating. |
| **Runner out of disk** | Docker images and build artifacts fill the runner disk. | Weekly cron job runs `docker system prune -af --volumes` on the runner. GitHub Actions cache auto-evicts after 7 days. |
| **Concurrent deployments** | Two merges to main happen within seconds. | GitHub Actions `concurrency` group on deploy job: `concurrency: { group: deploy-production, cancel-in-progress: false }`. Second deploy waits for first to complete. |
| **Secrets rotation** | JWT_SECRET or DATABASE_URL needs to change. | Update GitHub secret value. Re-run deploy pipeline. No workflow file changes needed. |
| **Health check timeout** | Server starts slowly after deploy. | Increase health check wait from 15s to 30s. Add retry loop (3 attempts, 10s apart) before declaring failure. |
| **Docker build cache miss** | Full rebuild takes 10+ minutes. | Use Docker layer caching with `actions/cache` for node_modules and Flutter pub cache. Multi-stage builds minimize rebuild scope. |
| **Branch migration conflicts** | Two PRs modify the same workflow file. | Standard git merge conflict resolution. Workflow files are YAML — merge carefully. |
| **Runner goes offline** | Self-hosted runner crashes or loses network. | GitHub Actions queues the job for up to 24 hours. Set up runner monitoring with a simple heartbeat script. |

---

## 7. Final QA Criteria
- [ ] Pushing to a feature branch triggers lint + test stages and completes successfully.
- [ ] Opening a PR to main triggers lint + test + build stages.
- [ ] Merging a PR to main triggers the full pipeline including deploy.
- [ ] A failing lint step prevents the test stage from running.
- [ ] A failing test prevents the build and deploy stages from running.
- [ ] Docker images are correctly tagged and pushed to GitHub Container Registry.
- [ ] Health check after deploy returns HTTP 200 from `/api/health`.
- [ ] A failed health check triggers automatic rollback to the previous deployment.
- [ ] All secrets are referenced via `${{ secrets.* }}` and never appear in logs.
- [ ] Android APK artifact is uploaded and downloadable from the GitHub Actions run.
- [ ] Concurrent merges to main do not cause parallel deployments.
- [ ] The self-hosted runner recovers gracefully after a reboot.

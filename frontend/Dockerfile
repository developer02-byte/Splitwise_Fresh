# ── Flutter Web Build Stage ──
FROM debian:latest AS build-env

# Install OS dependencies
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
       ca-certificates curl git wget unzip libstdc++6 libglu1-mesa fonts-droid-fallback python3 xz-utils \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

# Clone Flutter repository and set path
# Pin to 3.27.4 to match CI/CD and avoid breaking API changes
RUN git clone --depth 1 --branch 3.27.4 https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Pre-cache Flutter web artifacts
RUN flutter precache --web

# Setup working directory
WORKDIR /app
COPY pubspec.yaml pubspec.lock* ./
RUN flutter pub get

# Copy rest of source
COPY . .

# Generate Riverpod/Freezed codegen files
RUN dart run build_runner build --delete-conflicting-outputs || true

# Build arg for API URL — passed from docker-compose
ARG API_URL=http://localhost/api

# Compile to static HTML/JS/CSS web artifacts
RUN flutter build web --web-renderer canvaskit --release \
    --dart-define=API_URL=$API_URL

# ── Production Image (NGINX serving frontend + reverse proxy) ──
FROM nginx:alpine AS production
COPY --from=build-env /app/build/web /usr/share/nginx/html

EXPOSE 80
CMD ["nginx", "-g", "daemon off;"]

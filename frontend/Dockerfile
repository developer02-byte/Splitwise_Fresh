# ── Flutter Web Build Stage ──
FROM debian:latest AS build-env

# Install OS dependencies
RUN apt-get update 
RUN apt-get install -y curl git wget unzip libgconf-2-4 gdb libstdc++6 libglu1-mesa fonts-droid-fallback lib32stdc++6 python3 xz-utils
RUN apt-get clean

# Clone Flutter repository and set path
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Force use of a stable channel branch for production
RUN flutter channel stable && flutter upgrade

# Setup working directory
WORKDIR /app
COPY . .

# Run pub get and build web output
RUN flutter pub get

# Generate Riverpod/Freezed codegen files if any exist natively. Since we manually skipped in dev, this ensures the production build is perfectly compiled.
RUN flutter packages pub run build_runner build --delete-conflicting-outputs || true

# Compile to static HTML/JS/CSS web artifacts
# (Use CanvasKit renderer natively for high fidelity rendering)
RUN flutter build web --web-renderer canvaskit --release

# ── Production Image (NGINX Hosting) ──
FROM nginx:alpine AS production
COPY --from=build-env /app/build/web /usr/share/nginx/html

# Expose Nginx Port
EXPOSE 80

# Run
CMD ["nginx", "-g", "daemon off;"]

# Stage 1: Build the Flutter web app
FROM ghcr.io/cirruslabs/flutter:latest AS builder

ARG WS_URL=wss://swgame.hdrelhaj.com/ws

WORKDIR /app

# Cache pub dependencies
COPY pubspec.yaml pubspec.lock ./
COPY packages/engine_west/pubspec.yaml packages/engine_west/pubspec.yaml
COPY packages/engine_west/pubspec.lock packages/engine_west/pubspec.lock
RUN flutter pub get

# Build
COPY . .
RUN flutter build web --release --dart-define=WS_URL=${WS_URL}

# Stage 2: Serve with nginx
FROM nginx:alpine
COPY --from=builder /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80

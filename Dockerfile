# Stage 1: Build the Flutter web app
FROM cirrusci/flutter:stable AS builder

# Define build arguments for dart-define and base_href
ARG APP_ENV="prod" # Default value
ARG WEB_MAPS_API_KEY
ARG WEB_API_BASE_URL
ARG CHAT_SERVER_IP
ARG BASE_HREF="/cherryrecorder_client/" # Default base href

WORKDIR /app

COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

COPY . .

RUN echo "Building Flutter web with:" && \
    echo "APP_ENV: ${APP_ENV}" && \
    echo "WEB_API_BASE_URL: ${WEB_API_BASE_URL}" && \
    echo "CHAT_SERVER_IP: ${CHAT_SERVER_IP}" && \
    echo "BASE_HREF: ${BASE_HREF}" && \
    # WEB_MAPS_API_KEY is a secret, so not echoing it
    flutter build web --release --base-href "${BASE_HREF}" \
    --dart-define=APP_ENV=${APP_ENV} \
    --dart-define=WEB_MAPS_API_KEY=${WEB_MAPS_API_KEY} \
    --dart-define=WEB_API_BASE_URL=${WEB_API_BASE_URL} \
    --dart-define=CHAT_SERVER_IP=${CHAT_SERVER_IP}

# Stage 2: Serve the built app with Nginx
FROM nginx:alpine

# Copy custom Nginx configuration for SPA
COPY .docker/nginx.conf /etc/nginx/conf.d/default.conf

# Remove default Nginx welcome page content
RUN rm -rf /usr/share/nginx/html/*

# Copy built web app from builder stage
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"] 
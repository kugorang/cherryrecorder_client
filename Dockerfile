# Stage 1: Custom Flutter installation with Dart SDK 3.7.x
FROM ubuntu:22.04 AS builder

# Avoid interactive prompts during package installation
ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    openjdk-11-jdk-headless \
    cmake \
    ninja-build \
    clang \
    pkg-config \
    libgtk-3-dev \
    wget \
    && rm -rf /var/lib/apt/lists/*

# Define build arguments
ARG APP_ENV="prod"
ARG WEB_MAPS_API_KEY
ARG WEB_API_BASE_URL
ARG CHAT_SERVER_IP
ARG BASE_HREF="/cherryrecorder_client/"

# Set up Flutter
ENV FLUTTER_HOME=/flutter
ENV FLUTTER_VERSION=3.32.2
ENV PATH=$FLUTTER_HOME/bin:$PATH

# Download and set up Flutter - use specific version
RUN git clone https://github.com/flutter/flutter.git $FLUTTER_HOME && \
    cd $FLUTTER_HOME && \
    git checkout $FLUTTER_VERSION

# Run basic Flutter commands to finish setup
RUN flutter precache
RUN flutter doctor -v

WORKDIR /app

# Copy pubspec files and get dependencies
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy the rest of the application code
COPY . .

# Build web
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
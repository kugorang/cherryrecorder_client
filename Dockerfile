# Stage 1: Build Flutter app
FROM ubuntu:24.04 AS builder

ENV DEBIAN_FRONTEND=noninteractive

# Install dependencies
RUN apt-get update && apt-get install -y \
    curl \
    git \
    unzip \
    xz-utils \
    zip \
    libglu1-mesa \
    && rm -rf /var/lib/apt/lists/*

# Set up Flutter
ENV FLUTTER_HOME=/flutter
ENV FLUTTER_VERSION=3.32.2
ENV PATH=$FLUTTER_HOME/bin:$PATH

RUN git clone https://github.com/flutter/flutter.git $FLUTTER_HOME && \
    cd $FLUTTER_HOME && \
    git checkout $FLUTTER_VERSION

RUN flutter precache && flutter doctor -v

WORKDIR /app

# Copy pubspec files
COPY pubspec.yaml pubspec.lock ./
RUN flutter pub get

# Copy app code
COPY . .

# Build arguments
ARG BASE_HREF=/
ARG APP_ENV=prod
ARG WEB_MAPS_API_KEY
ARG WEB_API_BASE_URL
ARG WS_URL

# Build web app
RUN flutter build web --release --base-href "${BASE_HREF}" \
    --dart-define=APP_ENV=${APP_ENV} \
    --dart-define=WEB_MAPS_API_KEY=${WEB_MAPS_API_KEY} \
    --dart-define=WEB_API_BASE_URL=${WEB_API_BASE_URL} \
    --dart-define=WS_URL=${WS_URL}

# Stage 2: Serve with Nginx
FROM nginx:alpine

# Copy Nginx config
COPY .docker/nginx.conf /etc/nginx/conf.d/default.conf

# Remove default content
RUN rm -rf /usr/share/nginx/html/*

# Copy built app
COPY --from=builder /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

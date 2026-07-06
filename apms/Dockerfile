# Stage 1: Build the Flutter web application
FROM dart:stable AS build

WORKDIR /app

# Clone Flutter
RUN git clone https://github.com/flutter/flutter.git /usr/local/flutter
ENV PATH="/usr/local/flutter/bin:/usr/local/flutter/bin/cache/dart-sdk/bin:${PATH}"

# Run basic flutter setup
RUN flutter doctor -v
RUN flutter channel stable
RUN flutter upgrade

# Copy the app files
COPY . .

# Fetch dependencies and build
RUN flutter pub get
RUN flutter build web

# Stage 2: Serve the app using NGINX
FROM nginx:alpine

# Copy the built web files from the first stage
COPY --from=build /app/build/web /usr/share/nginx/html

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]

# =========================================================
# FRONT BUILD (Angular)
# =========================================================
FROM node:20-alpine AS front-build

WORKDIR /app/front

# Copy package files first (better Docker cache)
COPY front/package*.json ./

# Install dependencies
RUN npm ci

# Copy Angular source
COPY front/ .

# Build Angular app
RUN npm run build -- --configuration=production


# =========================================================
# BACK BUILD (Spring Boot / Gradle)
# =========================================================
FROM gradle:8.7-jdk17 AS back-build

WORKDIR /app/back

# Copy Gradle files first
COPY back/gradle ./gradle
COPY back/gradlew .
COPY back/build.gradle* .
COPY back/settings.gradle* .

# Give execution permission
RUN chmod +x gradlew

# Download dependencies (cache optimization)
RUN ./gradlew dependencies --no-daemon || true

# Copy source code
COPY back/ .

# Build application
RUN ./gradlew build -x test --no-daemon


# =========================================================
# FRONT RUNTIME (Caddy)
# =========================================================
FROM alpine:3.19 AS front

RUN apk add --no-cache caddy

WORKDIR /app

# Copy Angular build
COPY --from=front-build /app/front/dist/microcrm/browser ./front

# Copy Caddy config
COPY misc/docker/Caddyfile ./Caddyfile

EXPOSE 80
EXPOSE 443

CMD ["/usr/sbin/caddy", "run", "--config", "/app/Caddyfile"]


# =========================================================
# BACK RUNTIME (Java)
# =========================================================
FROM alpine:3.19 AS back

RUN apk add --no-cache openjdk17-jre-headless

WORKDIR /app

# Copy Spring Boot jar
COPY --from=back-build /app/back/build/libs/*.jar ./back/app.jar

EXPOSE 8080

CMD ["java", "-jar", "/app/back/app.jar"]


# =========================================================
# FULL STACK IMAGE (Supervisor)
# =========================================================
FROM alpine:3.19 AS standalone

RUN apk add --no-cache supervisor caddy openjdk17-jre-headless

WORKDIR /app

# Copy front runtime
COPY --from=front /app/front ./front
COPY --from=front /app/Caddyfile ./Caddyfile

# Copy backend runtime
COPY --from=back /app/back ./back

# Supervisor config
COPY misc/docker/supervisor.ini ./supervisor.ini

EXPOSE 80
EXPOSE 443
EXPOSE 8080

CMD ["/usr/bin/supervisord", "-c", "/app/supervisor.ini"]
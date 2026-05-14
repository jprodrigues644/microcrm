# =========================================================
# FRONT BUILD
# =========================================================
FROM node:20-alpine AS front-build

WORKDIR /app/front

COPY front/package*.json ./

RUN npm ci

COPY front/ .

RUN npm run build -- --configuration production


# =========================================================
# BACK BUILD
# =========================================================
FROM gradle:8.7-jdk17 AS back-build

WORKDIR /app/back

COPY back/gradle ./gradle
COPY back/gradlew .
COPY back/build.gradle* .
COPY back/settings.gradle* .

RUN chmod +x gradlew

RUN ./gradlew dependencies --no-daemon || true

#COPY back/

RUN ./gradlew build -x test --no-daemon


# =========================================================
# FRONT RUNTIME
# =========================================================
FROM alpine:3.19 AS front

RUN apk add --no-cache caddy

WORKDIR /app

COPY --from=front-build /app/front/dist ./front

COPY misc/docker/Caddyfile ./Caddyfile

EXPOSE 80 443

CMD ["/usr/sbin/caddy", "run", "--config", "/app/Caddyfile"]


# =========================================================
# BACK RUNTIME
# =========================================================
FROM alpine:3.19 AS back

RUN apk add --no-cache openjdk17-jre-headless

WORKDIR /app

COPY --from=back-build /app/back/build/libs/*.jar ./app.jar

EXPOSE 8080

CMD ["java", "-jar", "/app/app.jar"]


# =========================================================
# STANDALONE
# =========================================================
FROM alpine:3.19 AS standalone

RUN apk add --no-cache supervisor caddy openjdk17-jre-headless

WORKDIR /app

COPY --from=front /app/front ./front
COPY --from=front /app/Caddyfile ./Caddyfile

COPY --from=back /app/app.jar ./app.jar



EXPOSE 80 443 8080


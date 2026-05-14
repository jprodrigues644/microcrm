FROM node:20-alpine AS front-build
COPY ./front /src
WORKDIR /src
RUN npm ci \
    && npm run build -- --configuration=production

FROM gradle:jdk17 AS back-build
COPY ./back /src
WORKDIR /src
RUN ./gradlew build -x test

FROM alpine:3.19 AS front
COPY --from=front-build /src/dist/microcrm/browser /app/front
COPY misc/docker/Caddyfile /app/Caddyfile
RUN apk add caddy
WORKDIR /app
EXPOSE 80
EXPOSE 443
CMD ["/usr/sbin/caddy", "run"]

FROM alpine:3.19 AS back
COPY --from=back-build /src/build/libs/microcrm-0.0.1-SNAPSHOT.jar /app/back/microcrm-0.0.1-SNAPSHOT.jar
RUN apk add openjdk17-jre-headless
WORKDIR /app
EXPOSE 8080
CMD ["java", "-jar", "/app/back/microcrm-0.0.1-SNAPSHOT.jar"]

FROM alpine:3.19 AS standalone
COPY --from=front / /
COPY --from=back / /
COPY misc/docker/supervisor.ini /app/supervisor.ini
RUN apk add supervisor
WORKDIR /app
CMD ["/usr/bin/supervisord", "-c", "/app/supervisor.ini"]
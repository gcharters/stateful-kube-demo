FROM openliberty/open-liberty:kernel-java8-openj9-ubi

ARG VERSION=1.0
ARG REVISION=SNAPSHOT

LABEL \
  org.opencontainers.image.authors="Graham Charters" \
  org.opencontainers.image.url="local" \
  org.opencontainers.image.version="$VERSION" \
  org.opencontainers.image.revision="$REVISION" \
  name="cart-app" \
  version="$VERSION-$REVISION" \
  summary="A stateful cart application" \
  description="This image contains a stateful cart application running with the Open Liberty runtime."

COPY --chown=1001:0 src/main/liberty/config /config/
COPY --chown=1001:0 target/stateful-app.war /config/apps
COPY --chown=1001:0 target/hazelcast-*.jar /opt/ol/wlp/usr/shared/resources/hazelcast.jar

RUN configure.sh

RUN rm -rf /liberty/output/defaultServer/tranlog

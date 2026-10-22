ARG EMBEDDED_JAVA_VERSION=21
ARG BUILDPLATFORM=linux/amd64

FROM --platform=${BUILDPLATFORM} node:24-alpine AS builder

WORKDIR /src
COPY . /src

RUN apk add --no-cache wget &&\
    chmod a+x ./install-dependents.sh &&\
    chmod a+x ./build.sh &&\
    ./install-dependents.sh &&\
    ./build.sh &&\
    wget --input-file=lib-urls.txt --directory-prefix=production-code/daemon/lib/ &&\
    chmod a+x production-code/daemon/lib/*

FROM eclipse-temurin:${EMBEDDED_JAVA_VERSION}-jdk

ARG DEBIAN_FRONTEND=noninteractive
# Install pinned Node.js from the official tarball (includes npm). Avoids the
# NodeSource script: `curl | bash` swallows download failures (pipe exit code),
# silently falling back to the distro nodejs package which ships without npm.
RUN apt-get update && apt-get install -y --no-install-recommends curl ca-certificates xz-utils &&\
    ARCH=$(dpkg --print-architecture) &&\
    curl -fsSL -o /tmp/node.tar.xz https://nodejs.org/dist/v24.22.1/node-v24.22.1-linux-${ARCH}.tar.xz &&\
    tar -xJf /tmp/node.tar.xz --strip-components=1 -C /usr/local &&\
    rm /tmp/node.tar.xz &&\
    apt-get clean && rm -rf /var/lib/apt/lists/* &&\
    node -v && npm -v

WORKDIR /opt/mcsmanager/daemon

COPY --from=builder /src/production-code/daemon/ /opt/mcsmanager/daemon/

RUN npm install --production

EXPOSE 24444

ENV MCSM_INSTANCES_BASE_PATH=/opt/mcsmanager/daemon/data/InstanceData

VOLUME ["/opt/mcsmanager/daemon/data", "/opt/mcsmanager/daemon/logs"]

CMD [ "node", "app.js", "--max-old-space-size=8192" ]

ARG DOCKER_REPO=us-central1-docker.pkg.dev/botanix-391913/botanix-betanet-cometbft/botanix-betanet-cometbft
ARG DOCKER_TAG=v1

# Get dasel
FROM ghcr.io/tomwright/dasel:2-alpine AS dasel

FROM ${DOCKER_REPO}:${DOCKER_TAG} AS build

FROM debian:bookworm-slim

ARG USER=bitcoin-signing-server
ARG UID=10002

RUN apt-get update && DEBIAN_FRONTEND=noninteractive apt-get install -y curl

# Add user and group
RUN adduser \
    --disabled-password \
    --gecos "" \
    --shell "/bin/bash" \
    --uid "${UID}" \
    --home "/home/${USER}" \
    "${USER}" && \
    usermod -rG users ${USER}

VOLUME /bitcoin-signing-server/data
WORKDIR /bitcoin-server

RUN mkdir -p /bitcoin-server/config

# Set correct permissions.
COPY ./config.toml /bitcoin-server/config/config.toml
RUN chown -R ${USER}:${USER} /bitcoin-server && chmod -R 700 /bitcoin-server

# Cannot assume buildkit, hence no chmod
COPY ./docker-entrypoint.sh /usr/local/bin/

# Copy bins
COPY --from=build --chown=${USER}:${USER} /usr/local/bin/app /usr/local/bin/server
COPY --from=dasel --chown=${USER}:${USER} /usr/local/bin/dasel /usr/local/bin/

# Belt and suspenders
RUN chmod -R 755 /usr/local/bin/*

USER ${USER}

ENTRYPOINT ["/usr/local/bin/server"]

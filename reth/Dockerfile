ARG DOCKER_REPO=us-central1-docker.pkg.dev/botanix-391913/botanix-mainnet-node/botanix-reth
ARG DOCKER_TAG=latest

# Get dasel
FROM ghcr.io/tomwright/dasel:2-alpine AS dasel
FROM ${DOCKER_REPO}:${DOCKER_TAG} AS build

FROM debian:bookworm-slim

ARG USER=reth
ARG UID=10003

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

VOLUME /reth
WORKDIR /reth

RUN mkdir -p /reth/data
RUN mkdir /reth/config

# Set correct permissions.
RUN chown -R ${USER}:${USER} /reth && chmod -R 700 /reth

# Cannot assume buildkit, hence no chmod
COPY ./docker-entrypoint.sh /usr/local/bin/

# Copy bins
COPY --from=build --chown=${USER}:${USER} /usr/local/bin/app /usr/local/bin/reth
COPY --from=dasel --chown=${USER}:${USER} /usr/local/bin/dasel /usr/local/bin/

# Belt and suspenders
RUN chmod -R 755 /usr/local/bin/*

USER ${USER}

ENTRYPOINT ["reth"]

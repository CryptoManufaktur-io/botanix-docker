ARG DOCKER_REPO=us-central1-docker.pkg.dev/botanix-391913/botanix-betanet-cometbft/botanix-betanet-cometbft
ARG DOCKER_TAG=v1

# Get dasel
FROM ghcr.io/tomwright/dasel:2-alpine AS dasel

FROM ${DOCKER_REPO}:${DOCKER_TAG} AS build

FROM debian:bookworm-slim

ARG USER=cosmos
ARG UID=10001

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

VOLUME /cometbft

WORKDIR /cometbft

RUN mkdir /cometbft/config
RUN mkdir /cometbft/data

# Set correct permissions.
RUN chown -R ${USER}:${USER} /cometbft && chmod -R 700 /cometbft

# Cannot assume buildkit, hence no chmod
COPY ./docker-entrypoint.sh /usr/local/bin/
COPY ./config/genesis.json /cometbft/config/

# Copy bins
COPY --from=build --chown=${USER}:${USER} /usr/bin/cometbft /usr/local/bin/
COPY --from=dasel --chown=${USER}:${USER} /usr/local/bin/dasel /usr/local/bin/

# Belt and suspenders
RUN chmod -R 755 /usr/local/bin/*

USER ${USER}

ENTRYPOINT ["cometbft"]

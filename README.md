# Overview

Docker Compose for botanix-docker

Meant to be used with [central-proxy-docker](https://github.com/CryptoManufaktur-io/central-proxy-docker) for traefik
and Prometheus remote write; use `:ext-network.yml` in `COMPOSE_FILE` inside `.env` in that case.

If you want the RPC ports exposed locally, use `rpc-shared.yml` in `COMPOSE_FILE` inside `.env`.

## Quick Start

The `./botanixd` script can be used as a quick-start:

`./botanixd install` brings in docker-ce, if you don't have Docker installed already.

`cp default.env .env`

`nano .env` and adjust variables as needed.

### RPC node

- Add `botanix-rpc.yml` to `COMPOSE_FILE` to `.env`
- Place the `chain.toml` file on the `config/` folder for Reth.
- Place the `genesis.json` file in the `config/` folder for CometBFT.

### Validator node

- Add `botanix-validator.yml` to `COMPOSE_FILE` in `.env`
- Place the `chain.toml`, `discovery-secret` and `jwt.hex` files on the `config/` folder for Reth and bitcoin-signing-server.
- Place the `genesis.json` file in the `config/` folder for CometBFT.

If you're importing existing keys:

- Place the `node_key.json`, `priv_validator_key.json` and `priv_validator_state.json` files into the `keys/` folder for CometBFT.
- Run `docker compose run --rm import-cometbft-keys`
- If you have a bitcoin-signing-server `db` file backup, place it in `keys/bitcoin-signing-server` and run `docker compose run --rm import-btc-key`.

And finally:

`./botanixd up`

## Software update

To update the software, run `./botanixd update` and then `./botanixd up`

## Customization

`custom.yml` is not tracked by git and can be used to override anything in the provided yml files. If you use it,
add it to `COMPOSE_FILE` in `.env`

## Version

botanix-docker Docker uses a semver scheme.

This is botanix-docker Docker v1.1.1

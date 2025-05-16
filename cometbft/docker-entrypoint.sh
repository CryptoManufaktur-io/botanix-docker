#!/usr/bin/env bash
set -euo pipefail

if [[ ! -f /cometbft/.initialized ]]; then
  echo "Initializing!"

  # Init
  cometbft init -k "secp256k1" --home /cometbft
  cometbft show-node-id --home /cometbft

  dasel put -f /cometbft/config/config.toml -v "${MONIKER}" moniker
  dasel put -f /cometbft/config/config.toml -v "tcp://0.0.0.0:26658" proxy_app
  dasel put -f /cometbft/config/config.toml -v "3s" consensus.timeout_propose
  dasel put -f /cometbft/config/config.toml -v "1s" consensus.timeout_prevote
  dasel put -f /cometbft/config/config.toml -v "1s" consensus.timeout_precommit
  dasel put -f /cometbft/config/config.toml -v "1s" consensus.timeout_commit

  touch /cometbft/.initialized
else
  echo "Already initialized!"
fi

# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
exec "$@"

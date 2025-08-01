#!/usr/bin/env bash
set -euo pipefail

cp /config/genesis.json /cometbft/config/

if [[ ! -f /cometbft/.initialized ]]; then
  echo "Initializing!"

  # Init
  cometbft init -k "secp256k1" --home /cometbft
  cometbft show-node-id --home /cometbft

  dasel put -f /cometbft/config/config.toml -v "${MONIKER}" moniker
  dasel put -f /cometbft/config/config.toml -v "tcp://0.0.0.0:26658" proxy_app

  dasel put -f /cometbft/config/config.toml -v "tcp://0.0.0.0:${CL_P2P_PORT}" p2p.laddr

  dasel put -f /cometbft/config/config.toml -v "3s" consensus.timeout_propose
  dasel put -f /cometbft/config/config.toml -v "1s" consensus.timeout_prevote
  dasel put -f /cometbft/config/config.toml -v "1s" consensus.timeout_precommit
  dasel put -f /cometbft/config/config.toml -v "5s" consensus.timeout_commit

  dasel put -f /cometbft/config/config.toml -t bool -v false consensus.skip_timeout_commit

  dasel put -f /cometbft/config/config.toml -v "nop" mempool.type
  dasel put -f /cometbft/config/config.toml -v "" mempool.wal_dir

  dasel put -f /cometbft/config/config.toml -t bool -v true instrumentation.prometheus

  touch /cometbft/.initialized
else
  echo "Already initialized!"
fi

dasel put -f /cometbft/config/config.toml -v "${COMETBFT_PERSISTENT_PEERS}" p2p.persistent_peers
dasel put -f /cometbft/config/config.toml -v "${COMETBFT_UNCONDITIONAL_PEER_IDS}" p2p.unconditional_peer_ids
dasel put -f /cometbft/config/config.toml -t int -v 100 p2p.max_num_inbound_peers
dasel put -f /cometbft/config/config.toml -t int -v 20 p2p.max_num_outbound_peers

# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
exec "$@" ${COMETBFT_EXTRAS}

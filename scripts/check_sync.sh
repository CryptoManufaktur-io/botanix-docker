#!/usr/bin/env bash
set -Eeuo pipefail

# ── Defaults ──────────────────────────────────────────────────────────
COMPOSE_SERVICE=""
CONTAINER=""
LOCAL_RPC=""
PUBLIC_RPC=""
BLOCK_LAG_THRESHOLD=2
ENV_FILE=""
NO_INSTALL=0

# ── Usage ─────────────────────────────────────────────────────────────
usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Check whether the local Botanix (Reth) node is in sync.

Options:
  --compose-service <name>   Docker Compose service name (default: reth)
  --container <name>         Docker container name (skip Compose lookup)
  --local-rpc <url>          Local RPC endpoint
  --public-rpc <url>         Public RPC endpoint
  --block-lag <n>            Allowed block lag before "syncing" (default: 2)
  --env-file <path>          Path to env file to load variables from
  --no-install               Do not install curl/jq in the container
  -h|--help                  Show this help message
EOF
}

# ── Argument parsing ──────────────────────────────────────────────────
while [[ $# -gt 0 ]]; do
  case "$1" in
    --compose-service) COMPOSE_SERVICE="$2"; shift 2 ;;
    --container)       CONTAINER="$2";       shift 2 ;;
    --local-rpc)       LOCAL_RPC="$2";       shift 2 ;;
    --public-rpc)      PUBLIC_RPC="$2";      shift 2 ;;
    --block-lag)       BLOCK_LAG_THRESHOLD="$2"; shift 2 ;;
    --env-file)        ENV_FILE="$2";        shift 2 ;;
    --no-install)      NO_INSTALL=1;         shift ;;
    -h|--help)         usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage >&2; exit 2 ;;
  esac
done

# ── Safe env-file loader ─────────────────────────────────────────────
# Uses awk to extract simple KEY=VALUE pairs; never sources the file.
__load_env() {
  local file="$1"
  [[ -f "$file" ]] || return 0
  # Emit only lines matching ^WORD=... (skip comments, blanks, flags)
  local pairs
  pairs=$(awk -F= '/^[A-Za-z_][A-Za-z0-9_]*=/ {
    key = $1
    sub(/^[^=]+=/, "")
    gsub(/^["'\'']|["'\'']$/, "")   # strip surrounding quotes
    print key "=" $0
  }' "$file")
  while IFS='=' read -r key value; do
    [[ -z "$key" ]] && continue
    # Only set if not already overridden by a flag
    case "$key" in
      EL_RPC_PORT) if [[ -z "$LOCAL_RPC" ]]; then eval "export $key=\"$value\""; fi ;;
      PUBLIC_RPC)  if [[ -z "$PUBLIC_RPC" ]]; then PUBLIC_RPC="$value"; fi ;;
    esac
  done <<< "$pairs"
}

# Load env file
if [[ -n "$ENV_FILE" ]]; then
  __load_env "$ENV_FILE"
elif [[ -f ".env" ]]; then
  __load_env ".env"
fi

# ── Apply defaults after env loading ─────────────────────────────────
[[ -z "$COMPOSE_SERVICE" && -z "$CONTAINER" ]] && COMPOSE_SERVICE="reth"
[[ -z "$LOCAL_RPC" ]]  && LOCAL_RPC="http://127.0.0.1:${EL_RPC_PORT:-8545}"
[[ -z "$PUBLIC_RPC" ]] && PUBLIC_RPC="https://rpc.botanixlabs.com"

# ── Container helpers ─────────────────────────────────────────────────
__resolve_container() {
  if [[ -n "$CONTAINER" ]]; then
    return 0
  fi
  if [[ -n "$COMPOSE_SERVICE" ]]; then
    CONTAINER=$(docker compose ps -q "$COMPOSE_SERVICE" 2>/dev/null | head -1) || true
    if [[ -z "$CONTAINER" ]]; then
      echo "Could not find running container for compose service: $COMPOSE_SERVICE" >&2
      echo "Falling back to host execution" >&2
      COMPOSE_SERVICE=""
      return 0
    fi
  fi
}

__in_container() {
  [[ -n "$CONTAINER" ]]
}

__exec() {
  if __in_container; then
    docker exec -i "$CONTAINER" "$@"
  else
    "$@"
  fi
}

__exec_root() {
  if __in_container; then
    docker exec -u 0 "$CONTAINER" "$@"
  else
    "$@"
  fi
}

__install_tools() {
  if [[ "$NO_INSTALL" -eq 1 ]]; then
    return 0
  fi
  # Try apt (Debian/Ubuntu images)
  if __exec sh -c "command -v apt-get" >/dev/null 2>&1; then
    __exec_root sh -c "apt-get update -qq && apt-get install -y -qq curl jq >/dev/null 2>&1" || true
    return 0
  fi
  # Try apk (Alpine images)
  if __exec sh -c "command -v apk" >/dev/null 2>&1; then
    __exec_root sh -c "apk add --quiet curl jq" || true
    return 0
  fi
}

__check_tools() {
  local missing=0
  for tool in curl jq; do
    if ! __exec sh -c "command -v $tool" >/dev/null 2>&1; then
      missing=1
      break
    fi
  done
  if [[ "$missing" -eq 1 ]]; then
    __install_tools
    # Verify after install attempt
    for tool in curl jq; do
      if ! __exec sh -c "command -v $tool" >/dev/null 2>&1; then
        echo "Required tool '$tool' not available" >&2
        exit 2
      fi
    done
  fi
}

# ── RPC helpers ───────────────────────────────────────────────────────
__rpc_call() {
  local url="$1" method="$2" params="${3:-[]}"
  __exec curl -s -m 10 -X POST -H "Content-Type: application/json" \
    -d "{\"jsonrpc\":\"2.0\",\"id\":1,\"method\":\"$method\",\"params\":$params}" \
    "$url"
}

__hex_to_dec() {
  local hex="${1#0x}"
  printf '%d' "0x$hex" 2>/dev/null || echo "0"
}

# ── Main ──────────────────────────────────────────────────────────────
__resolve_container

# Check tools
if __in_container; then
  echo "⏳ Checking tools inside container"
  __check_tools
  echo "✅ Tools available in container"
  echo
fi

echo "⏳ Latest block comparison"

# Query eth_syncing on local
syncing_response=$(__rpc_call "$LOCAL_RPC" "eth_syncing") || {
  echo "Could not connect to local RPC at $LOCAL_RPC" >&2
  exit 2
}

syncing_result=$(echo "$syncing_response" | __exec jq -r '.result // empty') || true

# Query local latest block
local_block_response=$(__rpc_call "$LOCAL_RPC" "eth_getBlockByNumber" '["latest", false]') || {
  echo "Could not get latest block from local RPC" >&2
  exit 2
}

local_height_hex=$(echo "$local_block_response" | __exec jq -r '.result.number // empty') || true
local_hash=$(echo "$local_block_response" | __exec jq -r '.result.hash // empty') || true

if [[ -z "$local_height_hex" ]]; then
  echo "Local node returned no block data. Is the node running?" >&2
  exit 2
fi

local_height=$(__hex_to_dec "$local_height_hex")

# Query public latest block
public_block_response=$(__rpc_call "$PUBLIC_RPC" "eth_getBlockByNumber" '["latest", false]') || {
  echo "Could not connect to public RPC at $PUBLIC_RPC" >&2
  exit 2
}

public_height_hex=$(echo "$public_block_response" | __exec jq -r '.result.number // empty') || true
public_hash=$(echo "$public_block_response" | __exec jq -r '.result.hash // empty') || true

if [[ -z "$public_height_hex" ]]; then
  echo "Public RPC returned no block data" >&2
  exit 2
fi

public_height=$(__hex_to_dec "$public_height_hex")

# Compute lag
lag=$(( public_height - local_height ))
abs_lag=${lag#-}

if [[ "$lag" -gt 0 ]]; then
  direction="local behind"
elif [[ "$lag" -lt 0 ]]; then
  direction="local ahead"
else
  direction="in sync"
fi

echo "Local latest:  ${local_height} ${local_hash}"
echo "Public latest: ${public_height} ${public_hash}"
echo "Lag:           ${abs_lag} blocks (threshold: ${BLOCK_LAG_THRESHOLD}) (${direction})"
echo

# Determine sync status
is_syncing=0
if [[ "$syncing_result" != "false" && -n "$syncing_result" ]]; then
  is_syncing=1
fi
if [[ "$abs_lag" -gt "$BLOCK_LAG_THRESHOLD" ]]; then
  is_syncing=1
fi

if [[ "$is_syncing" -eq 0 ]]; then
  echo "✅ Final status: in sync"
  exit 0
else
  echo "⏳ Final status: syncing"
  exit 1
fi

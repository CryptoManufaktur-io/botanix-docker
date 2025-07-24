#!/usr/bin/env bash
set -euo pipefail

cp /config/* /bitcoin-server/config

# Word splitting is desired for the command line parameters
# shellcheck disable=SC2086
exec "$@"

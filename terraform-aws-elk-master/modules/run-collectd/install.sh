#!/usr/bin/env bash

set -e

readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RUN_COLLECTD_SCRIPT_FILE_PATH="$SCRIPT_PATH/bin/run-collectd"
readonly DEFAULT_COLLECTD_INSTALL_DIR="/usr/bin/"

chmod +x "$RUN_COLLECTD_SCRIPT_FILE_PATH"
sudo cp "$RUN_COLLECTD_SCRIPT_FILE_PATH" "$DEFAULT_COLLECTD_INSTALL_DIR"

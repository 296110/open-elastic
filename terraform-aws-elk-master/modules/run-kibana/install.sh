#!/usr/bin/env bash

set -e

readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RUN_KIBANA_SCRIPT_FILE_PATH="$SCRIPT_PATH/bin/run-kibana"
readonly DEFAULT_KIBANA_INSTALL_DIR="/usr/share/kibana/"

function install {
    chmod +x "$RUN_KIBANA_SCRIPT_FILE_PATH"
    sudo cp "$RUN_KIBANA_SCRIPT_FILE_PATH" "$DEFAULT_KIBANA_INSTALL_DIR/bin"
}

install
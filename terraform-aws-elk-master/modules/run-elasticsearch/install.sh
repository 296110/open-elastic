#!/usr/bin/env bash

set -e

readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RUN_ELASTICSEARCH_SCRIPT_FILE_PATH="$SCRIPT_PATH/bin/run-elasticsearch"
readonly DEFAULT_ELASTICSEARCH_INSTALL_DIR="/usr/share/elasticsearch/"

function install {
    chmod +x "$RUN_ELASTICSEARCH_SCRIPT_FILE_PATH"
    sudo cp "$RUN_ELASTICSEARCH_SCRIPT_FILE_PATH" "$DEFAULT_ELASTICSEARCH_INSTALL_DIR/bin"
}

install

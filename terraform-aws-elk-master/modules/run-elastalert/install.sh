#!/usr/bin/env bash

set -e

readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RUN_ELASTALERT_SCRIPT_FILE_PATH="$SCRIPT_PATH/bin/run-elastalert"

function install {
    chmod +x "$RUN_ELASTALERT_SCRIPT_FILE_PATH"
    sudo cp "$RUN_ELASTALERT_SCRIPT_FILE_PATH" "/usr/bin"
}

install
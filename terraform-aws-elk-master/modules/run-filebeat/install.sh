#!/usr/bin/env bash

set -e

readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RUN_FILEBEAT_SCRIPT_FILE_PATH="$SCRIPT_PATH/bin/run-filebeat"
readonly DEFAULT_FILEBEAT_INSTALL_DIR="/usr/bin/"

chmod +x "$RUN_FILEBEAT_SCRIPT_FILE_PATH"
sudo cp "$RUN_FILEBEAT_SCRIPT_FILE_PATH" "$DEFAULT_FILEBEAT_INSTALL_DIR"

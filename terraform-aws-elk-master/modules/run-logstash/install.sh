#!/usr/bin/env bash

set -e

readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly RUN_LOGSTASH_SCRIPT_FILE_PATH="$SCRIPT_PATH/bin/run-logstash"
readonly DEFAULT_LOGSTASH_INSTALL_DIR="/usr/share/logstash/bin"

chmod +x "$RUN_LOGSTASH_SCRIPT_FILE_PATH"
sudo cp "$RUN_LOGSTASH_SCRIPT_FILE_PATH" "$DEFAULT_LOGSTASH_INSTALL_DIR"

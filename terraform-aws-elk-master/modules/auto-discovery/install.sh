#!/usr/bin/env bash

set -e

readonly BASH_COMMONS_DIR="/opt/gruntwork/bash-commons"
readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly AUTO_DISCOVERY_SCRIPT_FILE_PATH="$SCRIPT_PATH/bin/auto-discovery"
readonly DEFAULT_AUTO_DISCOVERY_INSTALL_DIR="/usr/bin/"

if [[ ! -d "$BASH_COMMONS_DIR" ]]; then
  echo "ERROR: this script requires that bash-commons is installed in $BASH_COMMONS_DIR. See https://github.com/gruntwork-io/bash-commons for more info."
  exit 1
fi

source "$BASH_COMMONS_DIR/os.sh"

function install_dependencies_apt {
  sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get -y install awscli jq
}

function install_dependencies_yum {
  sudo yum update -y && sudo yum install -y awscli jq
}

if $(os_is_ubuntu); then
  install_dependencies_apt
elif $(os_is_amazon_linux); then
  install_dependencies_yum
elif $(os_is_centos); then
  install_dependencies_yum
else
  log_error "Could not find apt or yum. Cannot install dependencies on this OS."
  exit 1
fi

chmod +x "$AUTO_DISCOVERY_SCRIPT_FILE_PATH"
sudo cp "$AUTO_DISCOVERY_SCRIPT_FILE_PATH" "$DEFAULT_AUTO_DISCOVERY_INSTALL_DIR"

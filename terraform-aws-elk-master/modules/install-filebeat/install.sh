#!/usr/bin/env bash

set -e

# Import the appropriate bash commons libraries
readonly BASH_COMMONS_DIR="/opt/gruntwork/bash-commons"
readonly YUM_REPO_FILE_PATH="/etc/yum.repos.d/filebeat.repo"
readonly DEFAULT_FILEBEAT_VERSION="6.8.21"
readonly DEFAULT_TEMP_FILEBEAT_CONFIG_FILE_PATH="/tmp/config/filebeat.yml"
readonly DEFAULT_CONFIG_TEMPLATE_DESTINATION="/etc/filebeat"
readonly DEFAULT_FILEBEAT_CONFIG_FILE_PATH="/etc/filebeat/filebeat.yml"

if [[ ! -d "$BASH_COMMONS_DIR" ]]; then
  echo "ERROR: this script requires that bash-commons is installed in $BASH_COMMONS_DIR. See https://github.com/gruntwork-io/bash-commons for more info."
  exit 1
fi

source "$BASH_COMMONS_DIR/assert.sh"
source "$BASH_COMMONS_DIR/log.sh"
source "$BASH_COMMONS_DIR/os.sh"

function print_usage {
  echo
  echo "Usage: install-filebeat"
  echo
  echo "Install Filebeat on this machine."
  echo
  echo "Optional arguments:"
  echo
  echo -e "  --version\tThe version of Filebeat to install. Default: $DEFAULT_FILEBEAT_VERSION."
  echo -e "  --config-file\tThe path to the YAML config file for Filebeat, copied during Packer build. Default: $DEFAULT_TEMP_FILEBEAT_CONFIG_FILE_PATH."
  echo -e "  --ssl-config-dir\tOptional path to folder containing any trust/keystores/ssl certificates: $DEFAULT_CONFIG_TEMPLATE_DESTINATION."
  echo
  echo "Example:"
  echo
  echo "  install-filebeat  --version $DEFAULT_FILEBEAT_VERSION --config-file $DEFAULT_TEMP_FILEBEAT_CONFIG_FILE_PATH"
}

function add_filebeat_yum_repo {
  local -r version="$1"
  # We need to write a file to the given path with sudo permissions and using a heredoc, so we make clever use of
  # tee per https://stackoverflow.com/a/4414785/2308858
  log_info "Adding yum repo for Filebeat ${version:0:1}.x versions"
  sudo tee "$YUM_REPO_FILE_PATH" > /dev/null <<EOF
[elastic-${version:0:1}.x]
name=Elastic repository for ${version:0:1}.x packages
baseurl=https://artifacts.elastic.co/packages/${version:0:1}.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
}

function install_filebeat_with_yum {
  local -r version="$1"
  log_info "Installing Filebeat using yum"

  add_filebeat_yum_repo "$version"
  sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
  sudo yum update -y && sudo yum install -y "filebeat-${version}"
}

function install_filebeat_with_apt {
  local -r version="$1"
  log_info "Installing Filebeat using apt"

  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
  sudo apt-get install -y apt-transport-https
  echo "deb https://artifacts.elastic.co/packages/${version:0:1}.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-${version:0:1}.x.list
  sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "filebeat=${version}"

  # Disable filebeat on boot, as we will use run-filebeat to start the service
  sudo systemctl disable filebeat
}

function copy_ssl_artifacts {
  local -r ssl_source_dir="$1"

  sudo chmod 400 "$ssl_source_dir"/*
  sudo mv -v "$ssl_source_dir"/* "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
}

function install_filebeat {
  local version="$DEFAULT_FILEBEAT_VERSION"
  local config_file="$DEFAULT_TEMP_FILEBEAT_CONFIG_FILE_PATH"
  local ssl_config_dir=""

  while [[ $# > 0 ]]; do
    local key="$1"

    case "$key" in
      --help)
        print_usage
        exit
        ;;
      --version)
        assert_not_empty "$key" "$2"
        version="$2"
        shift
        ;;
      --config-file)
        assert_not_empty "$key" "$2"
        config_file="$2"
        shift
        ;;
      --ssl-config-dir)
        assert_not_empty "$key" "$2"
        ssl_config_dir="$2"
        shift
        ;;
      *)
        echo "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  assert_is_installed "sudo"
  assert_is_installed "curl"

  if $(os_is_ubuntu); then
    assert_is_installed "wget"
    install_filebeat_with_apt "$version"
  elif $(os_is_amazon_linux); then
    install_filebeat_with_yum "$version"
  elif $(os_is_centos); then
    install_filebeat_with_yum "$version"
  else
    log_error "Could not find apt or yum. Cannot install dependencies on this OS."
    exit 1
  fi

  sudo mv "$config_file" "$DEFAULT_FILEBEAT_CONFIG_FILE_PATH"

  if [[ ! -z "$ssl_config_dir" ]]; then
    copy_ssl_artifacts "$ssl_config_dir"
  fi

  # Filebeat requires the config file to be owned by root.
  # See here: https://www.elastic.co/guide/en/beats/libbeat/6.8/config-file-permissions.html
  sudo chown -R root:root "$(dirname "${DEFAULT_FILEBEAT_CONFIG_FILE_PATH}")"
  sudo chmod 0644 "$DEFAULT_FILEBEAT_CONFIG_FILE_PATH"
}

install_filebeat "$@"

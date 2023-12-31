#!/usr/bin/env bash

set -e

readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Import the appropriate bash commons libraries
readonly BASH_COMMONS_DIR="/opt/gruntwork/bash-commons"

if [[ ! -d "$BASH_COMMONS_DIR" ]]; then
  echo "ERROR: this script requires that bash-commons is installed in $BASH_COMMONS_DIR. See https://github.com/gruntwork-io/bash-commons for more info."
  exit 1
fi

source "$BASH_COMMONS_DIR/assert.sh"
source "$BASH_COMMONS_DIR/log.sh"
source "$BASH_COMMONS_DIR/os.sh"

readonly DEFAULT_ELASTALERT_VERSION="0.1.35"
readonly DEFAULT_CONFIG_TEMPLATE_SOURCE="/tmp/elastalert-config/config.yml"
readonly DEFAULT_ELASTALERT_RULES_SOURCE="/tmp/elastalert-rules"
readonly DEFAULT_CONFIG_TEMPLATE_DESTINATION="/etc/elastalert"


function print_usage {
  echo
  echo "Usage: install.sh"
  echo
  echo "Install ElastAlert on this machine."
  echo
  echo "Optional arguments:"
  echo
  echo -e "  --version\tThe version of ElastAlert to install. Default: $DEFAULT_ELASTALERT_VERSION."
  echo -e "  --config-file\tOptional path to a templated ElastAlert config file (config.yml). Default: $DEFAULT_CONFIG_TEMPLATE_SOURCE."
  echo -e "  --rules-folder\tOptional path to a folder containing templated ElastAlert rules ([rule-name].yml). Default: $DEFAULT_ELASTALERT_RULES_SOURCE."
  echo -e "  --ssl-config-dir\tOptional path to folder containing any trust/keystores/ssl certificates: $DEFAULT_CONFIG_TEMPLATE_DESTINATION."
  echo
  echo "Example:"
  echo
  echo "  install.sh --version $DEFAULT_ELASTALERT_VERSION"
}

function install_elastalert_with_pip {
  local -r version="$1"

  log_info "Installing ElastAlert $version using pip"
  sudo -H pip3 install "elastalert==$version"
}

function install_dependencies_with_apt {
  sudo apt-get -y update
  sudo apt-get install -y python3-dev gcc python3-pip build-essential
}

function install_dependencies_with_yum {
  sudo yum update -y
  sudo yum install -y python3 python3-pip python3-devel gcc
}

function install_template_config_files {
  local -r config_file_path="$1"

  sudo mkdir -p "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
  sudo mv "$config_file_path" "$DEFAULT_CONFIG_TEMPLATE_DESTINATION/config.yml"
}

function create_elastalert_supervisord_service {
  local -r config_file_path="$1"
  local elastalert_executable_path="$(which elastalert)"

  # We need to write a file to the given path with sudo permissions and using a heredoc, so we make clever use of
  # tee per https://stackoverflow.com/a/4414785/2308858
  log_info "Adding Supervisord service for ElastAlert."
  sudo tee "/lib/systemd/system/elastalert.service" > /dev/null <<EOF
[Unit]
Description=ElastAlert process
After=syslog.target
After=network.target

[Service]
ExecStart=$elastalert_executable_path --config $config_file_path --verbose
Restart=on-failure
StandardOutput=syslog
StandardError=syslog
SyslogIdentifier=elastalert
Type=simple

# Give a reasonable amount of time for the server to start up/shut down
TimeoutSec=60

[Install]
WantedBy=multi-user.target
EOF
}

function copy_ssl_artifacts {
  local -r ssl_source_dir="$1"

  sudo chmod 400 "$ssl_source_dir"/*
  sudo mv -v "$ssl_source_dir"/* "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
}

function install_template_rules {
  local -r rules_template_path="$1"

  sudo mv "$rules_template_path" "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
}

function install {
  local version="$DEFAULT_ELASTALERT_VERSION"
  local config_file_template="$DEFAULT_CONFIG_TEMPLATE_SOURCE"
  local rules_template_folder="$DEFAULT_ELASTALERT_RULES_SOURCE"


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
        config_file_template="$2"
        shift
        ;;
      --rules-folder)
        assert_not_empty "$key" "$2"
        config_file_template="$2"
        shift
        ;;
      --ssl-config-dir)
        assert_not_empty "$key" "$2"
        ssl_config_dir="$2"
        shift
        ;;
      *)
        log_error "Unrecognized argument: $key"
        print_usage
        exit 1
        ;;
    esac

    shift
  done

  if $(os_is_ubuntu); then
    install_dependencies_with_apt
  elif $(os_is_amazon_linux "2"); then
    install_dependencies_with_yum
  elif $(os_is_centos); then
    install_dependencies_with_yum
  else
    log_error "This script only supports Ubuntu, Amazon Linux 2, and CentOS"
    exit 1
  fi

  assert_is_installed "python3"
  assert_is_installed "pip3"

  install_elastalert_with_pip "$version"

  install_template_config_files "$config_file_template"

  create_elastalert_supervisord_service "$DEFAULT_CONFIG_TEMPLATE_DESTINATION/config.yml"

  install_template_rules "$rules_template_folder"

  if [[ ! -z "$ssl_config_dir" ]]; then
    copy_ssl_artifacts "$ssl_config_dir"
  fi
}

install "$@"

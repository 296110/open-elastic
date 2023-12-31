#!/usr/bin/env bash

set -e

# Import the appropriate bash commons libraries
readonly BASH_COMMONS_DIR="/opt/gruntwork/bash-commons"
readonly DEFAULT_COLLECTD_VERSION_APT="5.9.2"
readonly DEFAULT_COLLECTD_VERSION_YUM="5.8.0"
readonly DEFAULT_TEMP_COLLECTD_CONFIG_FILE_PATH="/tmp/config/collectd.conf"
readonly DEFAULT_CONFIG_TEMPLATE_DESTINATION="/etc/collectd"

if [[ ! -d "$BASH_COMMONS_DIR" ]]; then
  echo "ERROR: this script requires that bash-commons is installed in $BASH_COMMONS_DIR. See https://github.com/gruntwork-io/bash-commons for more info."
  exit 1
fi

source "$BASH_COMMONS_DIR/assert.sh"
source "$BASH_COMMONS_DIR/log.sh"
source "$BASH_COMMONS_DIR/os.sh"

function print_usage {
  echo
  echo "Usage: install-collectd"
  echo
  echo "Install CollectD on this machine."
  echo
  echo "Optional arguments:"
  echo
  echo -e "  --apt-version\tThe version of CollectD to install with apt-get. Default: $DEFAULT_COLLECTD_VERSION_APT."
  echo -e "  --yum-version\tThe version of CollectD to install with yum. Default: $DEFAULT_COLLECTD_VERSION_YUM."
  echo -e "  --config-file\tThe path to the YAML config file for CollectD, copied during Packer build. Default: $DEFAULT_TEMP_COLLECTD_CONFIG_FILE_PATH."
  echo
  echo "Example:"
  echo
  echo "  install-collectd --config-file $DEFAULT_TEMP_COLLECTD_CONFIG_FILE_PATH"
}

function install_collectd_with_yum {
  local -r version="$1"
  local -r config_file="$2"

  log_info "Installing CollectD using yum"

  sudo wget http://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
  sudo rpm -ivh epel-release-latest-7.noarch.rpm
  sudo yum update -y && sudo yum install -y "collectd-${version}"

  sudo mv "$config_file" "/etc/collectd.conf"
}

function install_collectd_with_apt {
  local -r version="$1"
  local -r config_file="$2"

  log_info "Installing CollectD using apt"

  sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "collectd=${version}*"

  sudo mv "$config_file" "/etc/collectd/collectd.conf"
}

function copy_ssl_artifacts {
  local -r ssl_source_dir="$1"

  sudo chmod 400 "$ssl_source_dir"/*
  sudo mv -v "$ssl_source_dir"/* "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
}

function install_collectd {
    local apt_version="$DEFAULT_COLLECTD_VERSION_APT"
    local yum_version="$DEFAULT_COLLECTD_VERSION_YUM"
    local config_file="$DEFAULT_TEMP_COLLECTD_CONFIG_FILE_PATH"
    local ssl_config_dir=""

    while [[ $# > 0 ]]; do
        local key="$1"

        case "$key" in
          --help)
            print_usage
            exit
            ;;
          --apt-version)
            assert_not_empty "$key" "$2"
            apt_version="$2"
            shift
            ;;
          --yum-version)
            assert_not_empty "$key" "$2"
            yum_version="$2"
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

    if $(os_is_ubuntu); then
        install_collectd_with_apt "$apt_version" "$config_file"
    elif $(os_is_amazon_linux); then
        assert_is_installed "wget"
        install_collectd_with_yum "$yum_version" "$config_file"
    elif $(os_is_centos); then
        assert_is_installed "wget"
        install_collectd_with_yum "$yum_version" "$config_file"
    else
        log_error "Could not find apt or yum. Cannot install dependencies on this OS."
        exit 1
    fi

    if [[ ! -z "$ssl_config_dir" ]]; then
      copy_ssl_artifacts "$ssl_config_dir"
    fi
}

install_collectd "$@"

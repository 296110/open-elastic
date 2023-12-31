#!/usr/bin/env bash

set -e

readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly YUM_REPO_FILE_PATH="/etc/yum.repos.d/kibana.repo"

# Import the appropriate bash commons libraries
readonly BASH_COMMONS_DIR="/opt/gruntwork/bash-commons"

if [[ ! -d "$BASH_COMMONS_DIR" ]]; then
  echo "ERROR: this script requires that bash-commons is installed in $BASH_COMMONS_DIR. See https://github.com/gruntwork-io/bash-commons for more info."
  exit 1
fi

source "$BASH_COMMONS_DIR/assert.sh"
source "$BASH_COMMONS_DIR/log.sh"
source "$BASH_COMMONS_DIR/os.sh"

readonly DEFAULT_KIBANA_INSTALL_DIR="/usr/share/kibana"
readonly DEFAULT_CONFIG_TEMPLATE_DESTINATION="/etc/kibana/"
readonly DEFAULT_CONFIG_TEMPLATE_SOURCE="/tmp/config/kibana.yml"
readonly DEFAULT_KIBANA_VERSION="6.8.21"

function print_usage {
  echo
  echo "Usage: install.sh"
  echo
  echo "Install Kibana on this machine."
  echo
  echo "Optional arguments:"
  echo
  echo -e "  --version\tThe version of Kibana to install. Default: $DEFAULT_KIBANA_VERSION."
  echo -e "  --config-file\tOptional path to a templated Kibana config file (kibana.yml). Default: $DEFAULT_CONFIG_TEMPLATE_SOURCE."
  echo -e "  --ssl-config-dir\tOptional path to folder containing any trust/keystores/ssl certificates: $DEFAULT_CONFIG_TEMPLATE_DESTINATION."
  echo
  echo "Example:"
  echo
  echo "  install.sh --version $DEFAULT_KIBANA_VERSION --config $DEFAULT_CONFIG_TEMPLATE_SOURCE"
}


function add_kibana_yum_repo {
  local -r version="$1"
  local -r major_version="${version:0:1}"

  # We need to write a file to the given path with sudo permissions and using a heredoc, so we make clever use of
  # tee per https://stackoverflow.com/a/4414785/2308858
  log_info "Adding yum repo for Kibana $major_version.x versions"
  sudo tee "$YUM_REPO_FILE_PATH" > /dev/null <<EOF
[kibana-$major_version.x]
name=Kibana repository for $major_version.x packages
baseurl=https://artifacts.elastic.co/packages/$major_version.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
}

function install_kibana_with_yum {
  local -r version="$1"
  log_info "Installing Kibana $version using yum"

  add_kibana_yum_repo "$version"
  sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
  sudo yum install -y "kibana-${version}"
}

function install_kibana_with_apt {
  local -r version="$1"
  local -r major_version="${version:0:1}"

  log_info "Installing Kibana $version using apt"

  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
  sudo apt-get install -y apt-transport-https
  echo "deb https://artifacts.elastic.co/packages/$major_version.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list

  sudo apt-get update
  sudo apt-get -y install "kibana=${version}"
}

function install_template_config_files {
  local -r config_file_path="$1"

  sudo mkdir -p "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
  sudo mv "$config_file_path" "$DEFAULT_CONFIG_TEMPLATE_DESTINATION/kibana.yml"
}

function copy_ssl_artifacts {
  local -r ssl_source_dir="$1"

  sudo chown kibana "$ssl_source_dir"/*
  sudo chmod 400 "$ssl_source_dir"/*
  sudo mv -v "$ssl_source_dir"/* "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
}

function install {
  local version="$DEFAULT_KIBANA_VERSION"
  local config_file_template="$DEFAULT_CONFIG_TEMPLATE_SOURCE"
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

  assert_is_installed "sudo"
  assert_is_installed "curl"

  if $(os_is_ubuntu); then
      assert_is_installed "wget"
      install_kibana_with_apt "$version"
  elif $(os_is_amazon_linux "2"); then
      install_kibana_with_yum "$version"
  elif $(os_is_centos); then
      install_kibana_with_yum "$version"
  else
      log_error "This script only supports Ubuntu, Amazon Linux 2, and CentOS"
      exit 1
  fi

  install_template_config_files "$config_file_template"

  if [[ ! -z "$ssl_config_dir" ]]; then
    copy_ssl_artifacts "$ssl_config_dir"
  fi

  # Add a log placeholder so that when Kibana starts up,
  # it can be directed to log to that location as well
  sudo mkdir -p /var/log/kibana/
  sudo touch /var/log/kibana/kibana.log
  sudo chown kibana:kibana /var/log/kibana/kibana.log
}

install "$@"

#!/usr/bin/env bash

set -e

readonly SCRIPT_PATH="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly YUM_REPO_FILE_PATH="/etc/yum.repos.d/elasticsearch.repo"

# Import the appropriate bash commons libraries
readonly BASH_COMMONS_DIR="/opt/gruntwork/bash-commons"

if [[ ! -d "$BASH_COMMONS_DIR" ]]; then
  echo "ERROR: this script requires that bash-commons is installed in $BASH_COMMONS_DIR. See https://github.com/gruntwork-io/bash-commons for more info."
  exit 1
fi

source "$BASH_COMMONS_DIR/assert.sh"
source "$BASH_COMMONS_DIR/log.sh"
source "$BASH_COMMONS_DIR/os.sh"

readonly DEFAULT_JVM_CONFIG_TEMPLATE_SOURCE="/tmp/config/jvm.options"
readonly DEFAULT_CONFIG_TEMPLATE_SOURCE="/tmp/config/elasticsearch.yml"
readonly DEFAULT_ELASTICSEARCH_INSTALL_DIR="/usr/share/elasticsearch"
readonly DEFAULT_CONFIG_TEMPLATE_DESTINATION="/etc/elasticsearch"
readonly DEFAULT_ELASTICSEARCH_VERSION="6.8.21"

function print_usage {
  echo
  echo "Usage: install.sh"
  echo
  echo "This script can be used to install Elasticsearch as well as Elasticsearch plugins. This script has been tested with Ubuntu 20.04 + 18.04, Amazon Linux 2, and CentOS 7."
  echo
  echo "Optional arguments:"
  echo
  echo -e "  --version\tThe version of Elasticsearch to install. Default: $DEFAULT_ELASTICSEARCH_VERSION."
  echo -e "  --config-file\tOptional path to a templated Elasticsearcg config file (elasticsearch.yml). Default: $DEFAULT_CONFIG_TEMPLATE_SOURCE."
  echo -e "  --jvm-config-file\tOptional path to a templated JVM config file (jvm.options). Default: $DEFAULT_JVM_CONFIG_TEMPLATE_SOURCE."
  echo -e "  --plugin\tOptional name of Elasticsearch plugin to install. Can also specify absolute path like: \"file:///tmp/plugin-X.Y.Z.zip\". May be repeated"
  echo -e "  --plugin-config-dir\tOptional path to folder containing any extra plugin config files. All files from this folder will be moved to: $DEFAULT_CONFIG_TEMPLATE_DESTINATION."
  echo
  echo "Example:"
  echo
  echo "  install.sh --version $DEFAULT_ELASTICSEARCH_VERSION --config-file $DEFAULT_CONFIG_TEMPLATE_SOURCE --jvm-config-file $DEFAULT_JVM_CONFIG_TEMPLATE_SOURCE --plugin discovery-ec2"
}


function add_elasticsearch_yum_repo {
  local -r version="$1"
  local -r major_version="${version:0:1}"

  # We need to write a file to the given path with sudo permissions and using a heredoc, so we make clever use of
  # tee per https://stackoverflow.com/a/4414785/2308858
  log_info "Adding yum repo for Elasticsearch $major_version.x versions"
  sudo tee "$YUM_REPO_FILE_PATH" > /dev/null <<EOF
[elasticsearch-$major_version.x]
name=Elasticsearch repository for $major_version.x packages
baseurl=https://artifacts.elastic.co/packages/$major_version.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
}

function install_elasticsearch_with_yum {
  local -r version="$1"
  log_info "Installing Elasticsearch $version using yum"

  add_elasticsearch_yum_repo "$version"
  sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch

  sudo yum update -y
  sudo yum install -y "elasticsearch-${version}"
}

function install_elasticsearch_with_apt {
  local -r version="$1"
  local -r major_version="${version:0:1}"
  log_info "Installing Elasticsearch $version using apt"

  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
  sudo apt-get install -y apt-transport-https
  echo "deb https://artifacts.elastic.co/packages/$major_version.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-6.x.list

  sudo apt-get update
  sudo apt-get -y install "elasticsearch=${version}"
}

function copy_plugin_config_files {
    local -r plugin_config_dir="$1"
    sudo mv -v "$plugin_config_dir"/* "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
}

function copy_ssl_artifacts {
  local -r ssl_source_dir="$1"

  sudo chown elasticsearch "$ssl_source_dir"/*
  sudo chmod 400 "$ssl_source_dir"/*
  sudo mv -v "$ssl_source_dir"/* "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
}

function install_template_config_files {
  local -r config_file_path="$1"
  local -r jvm_config_file_path="$2"

  sudo mkdir -p "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
  sudo mv "$config_file_path" "$DEFAULT_CONFIG_TEMPLATE_DESTINATION/elasticsearch.yml"
  sudo mv "$jvm_config_file_path" "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
}

function install_plugin {
  local -r pluginName="$1"
  log_info "Installing plugin: $pluginName"

  sudo $DEFAULT_ELASTICSEARCH_INSTALL_DIR/bin/elasticsearch-plugin install --batch "$pluginName"
}

function install {
  local version="$DEFAULT_ELASTICSEARCH_VERSION"
  local config_file_template="$DEFAULT_CONFIG_TEMPLATE_SOURCE"
  local jvm_config_file_template="$DEFAULT_JVM_CONFIG_TEMPLATE_SOURCE"
  local plugins_to_install=()
  local plugin_config_dir=""
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
      --jvm-config-file)
        assert_not_empty "$key" "$2"
        jvm_config_file_template="$2"
        shift
        ;;
      --plugin)
        assert_not_empty "$key" "$2"
        plugins_to_install+=("$2")
        shift
        ;;
      --plugin-config-dir)
        assert_not_empty "$key" "$2"
        plugin_config_dir="$2"
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
      install_elasticsearch_with_apt "$version"
  elif $(os_is_amazon_linux "2"); then
      install_elasticsearch_with_yum "$version"
  elif $(os_is_centos); then
      install_elasticsearch_with_yum "$version"
  else
      log_error "Could not find apt or yum. Cannot install dependencies on this OS."
      exit 1
  fi

  install_template_config_files "$config_file_template" "$jvm_config_file_template"

  if [[ ! -z "$plugin_config_dir" ]]; then
      copy_plugin_config_files "$plugin_config_dir"
  fi

  if [[ ! -z "$ssl_config_dir" ]]; then
    copy_ssl_artifacts "$ssl_config_dir"
  fi


  # Process and install all plugins
  for pluginName in "${plugins_to_install[@]}"; do
      install_plugin "$pluginName"
  done

  # Elasticsearch will be run as `elasticsearch` user when started with systemd
  # Make sure that `elasticsearch` user has permission to access its own install dir.
  sudo chown elasticsearch:elasticsearch -R "$DEFAULT_ELASTICSEARCH_INSTALL_DIR"
}

install "$@"

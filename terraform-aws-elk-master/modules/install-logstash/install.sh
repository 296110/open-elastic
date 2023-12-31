#!/usr/bin/env bash

set -e

# Import the appropriate bash commons libraries
readonly BASH_COMMONS_DIR="/opt/gruntwork/bash-commons"
readonly YUM_REPO_FILE_PATH="/etc/yum.repos.d/logstash.repo"
readonly DEFAULT_LOGSTASH_VERSION="6.8.21-1"
readonly DEFAULT_TEMP_LOGSTASH_CONFIG_FILE_PATH="/tmp/config/logstash.yml"
readonly DEFAULT_CONFIG_TEMPLATE_DESTINATION="/etc/logstash"
readonly DEFAULT_LOGSTASH_CONFIG_FILE_PATH="/etc/logstash/logstash.yml"
readonly DEFAULT_LOGSTASH_INSTALL_DIR="/usr/share/logstash"
readonly DEFAULT_TEMP_LOGSTASH_PIPELINE_CONFIG_FILE_PATH="/tmp/config/pipeline.conf"
readonly DEFAULT_LOGSTASH_PIPELINE_CONFIG_FILE_PATH="/etc/logstash/conf.d/pipeline.conf"
readonly DEFAULT_JVM_CONFIG_TEMPLATE_SOURCE_FILE_PATH="/tmp/config/jvm.options"
readonly DEFAULT_JVM_CONFIG_FILE_PATH="/etc/logstash/jvm.options"

if [[ ! -d "$BASH_COMMONS_DIR" ]]; then
  echo "ERROR: this script requires that bash-commons is installed in $BASH_COMMONS_DIR. See https://github.com/gruntwork-io/bash-commons for more info."
  exit 1
fi

source "$BASH_COMMONS_DIR/assert.sh"
source "$BASH_COMMONS_DIR/log.sh"
source "$BASH_COMMONS_DIR/os.sh"

function print_usage {
  echo
  echo "Usage: install-logstash"
  echo
  echo "Install Logstash on this machine."
  echo
  echo "Optional arguments:"
  echo
  echo -e "  --version\tThe version of Logstash to install. Default: $DEFAULT_LOGSTASH_VERSION."
  echo -e "  --config-file\tThe path to the YAML config file for Logstash, copied during Packer build. Default: $DEFAULT_TEMP_LOGSTASH_CONFIG_FILE_PATH."
  echo -e "  --jvm-config-file\tOptional path to a templated JVM config file (jvm.options). Default: $DEFAULT_JVM_CONFIG_FILE_PATH."
  echo -e "  --pipeline-config-file\tThe path to the pipeline config file for Logstash, copied during Packer build. Default: $DEFAULT_TEMP_LOGSTASH_PIPELINE_CONFIG_FILE_PATH."
  echo -e "  --ssl-config-dir\tOptional path to folder containing any trust/keystores/ssl certificates: $DEFAULT_CONFIG_TEMPLATE_DESTINATION."
  echo -e "  --plugin\tOptional name of Elasticsearch plugin to install. Currently only supports plugins on http://rubygems.org/. May be repeated"

  echo
  echo "Example:"
  echo
  echo "  install-logstash  --version $DEFAULT_LOGSTASH_VERSION --config-file $DEFAULT_TEMP_LOGSTASH_CONFIG_FILE_PATH --jvm-config-file $DEFAULT_JVM_CONFIG_TEMPLATE_SOURCE --pipeline-config-file $DEFAULT_TEMP_LOGSTASH_PIPELINE_CONFIG_FILE_PATH"
}

function add_logstash_yum_repo {
  local -r version="$1"
  # We need to write a file to the given path with sudo permissions and using a heredoc, so we make clever use of
  # tee per https://stackoverflow.com/a/4414785/2308858
  log_info "Adding yum repo for Logstash ${version:0:1}.x versions"
  sudo tee "$YUM_REPO_FILE_PATH" > /dev/null <<EOF
[logstash-${version:0:1}.x]
name=Elastic repository for ${version:0:1}.x packages
baseurl=https://artifacts.elastic.co/packages/${version:0:1}.x/yum
gpgcheck=1
gpgkey=https://artifacts.elastic.co/GPG-KEY-elasticsearch
enabled=1
autorefresh=1
type=rpm-md
EOF
}

function install_logstash_with_yum {
  local -r version="$1"
  log_info "Installing Logstash using yum"

  add_logstash_yum_repo "$version"
  sudo rpm --import https://artifacts.elastic.co/GPG-KEY-elasticsearch
  sudo yum update -y && sudo yum install -y "logstash-${version}"
}

function install_logstash_with_apt {
  local -r version="$1"
  log_info "Installing Logstash using apt"

  wget -qO - https://artifacts.elastic.co/GPG-KEY-elasticsearch | sudo apt-key add -
  sudo apt-get install -y apt-transport-https
  echo "deb https://artifacts.elastic.co/packages/${version:0:1}.x/apt stable main" | sudo tee -a /etc/apt/sources.list.d/elastic-${version:0:1}.x.list
  sudo DEBIAN_FRONTEND=noninteractive apt-get update && sudo DEBIAN_FRONTEND=noninteractive apt-get -y install "logstash=1:${version}"
}

function copy_ssl_artifacts {
  local -r ssl_source_dir="$1"

  sudo chown logstash "$ssl_source_dir"/*
  sudo chmod 400 "$ssl_source_dir"/*
  sudo mv -v "$ssl_source_dir"/* "$DEFAULT_CONFIG_TEMPLATE_DESTINATION"
}

function install_logstash_plugin {
  local -r plugin="$1"
  log_info "Installing plugin: $plugin"
  sudo $DEFAULT_LOGSTASH_INSTALL_DIR/bin/logstash-plugin install "$plugin"
}

function update_input_plugin {
  sudo $DEFAULT_LOGSTASH_INSTALL_DIR/bin/logstash-plugin update logstash-input-beats
}

function install_jvm_template_config_files {
  local -r jvm_config_file_path="$1"

  sudo mv "$jvm_config_file_template" "$DEFAULT_JVM_CONFIG_FILE_PATH"
  sudo chmod 0644 "$DEFAULT_JVM_CONFIG_FILE_PATH"
}

function install_logstash {
  local version="$DEFAULT_LOGSTASH_VERSION"
  local config_file="$DEFAULT_TEMP_LOGSTASH_CONFIG_FILE_PATH"
  local jvm_config_file_template="$DEFAULT_JVM_CONFIG_TEMPLATE_SOURCE_FILE_PATH"
  local pipeline_config_file="$DEFAULT_TEMP_LOGSTASH_PIPELINE_CONFIG_FILE_PATH"
  local ssl_config_dir=""
  local plugins_to_install=()

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
      --jvm-config-file)
        assert_not_empty "$key" "$2"
        jvm_config_file_template="$2"
        shift
        ;;
      --pipeline-config-file)
        assert_not_empty "$key" "$2"
        pipeline_config_file="$2"
        shift
        ;;
      --ssl-config-dir)
        assert_not_empty "$key" "$2"
        ssl_config_dir="$2"
        shift
        ;;
      --plugin)
        assert_not_empty "$key" "$2"
        plugins_to_install+=("$2")
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
    install_logstash_with_apt "$version"
  elif $(os_is_amazon_linux); then
    install_logstash_with_yum "$version"
  elif $(os_is_centos); then
    install_logstash_with_yum "$version"
  else
    log_error "Could not find apt or yum. Cannot install dependencies on this OS."
    exit 1
  fi

    # Process and install all plugins
  for plugin in "${plugins_to_install[@]}"; do
      install_logstash_plugin "$plugin"
  done

  sudo mv "$config_file" "$DEFAULT_LOGSTASH_CONFIG_FILE_PATH"
  sudo mv "$pipeline_config_file" "$DEFAULT_LOGSTASH_PIPELINE_CONFIG_FILE_PATH"

  # Logstash requires the config files to be owned by root.
  sudo chown -R root:root "$(dirname "${DEFAULT_LOGSTASH_CONFIG_FILE_PATH}")"
  sudo chmod 0644 "$DEFAULT_LOGSTASH_CONFIG_FILE_PATH"
  sudo chown -R root:root "$(dirname "${DEFAULT_LOGSTASH_PIPELINE_CONFIG_FILE_PATH}")"
  sudo chmod 0644 "$DEFAULT_LOGSTASH_PIPELINE_CONFIG_FILE_PATH"

  # The ssl certificates need to be read only and owned by logstash user.
  if [[ ! -z "$ssl_config_dir" ]]; then
    copy_ssl_artifacts "$ssl_config_dir"
  fi

  # Install the latest version of the
  update_input_plugin

  # Insert jvm config template file
  install_jvm_template_config_files "$jvm_config_file_template"
}

install_logstash "$@"

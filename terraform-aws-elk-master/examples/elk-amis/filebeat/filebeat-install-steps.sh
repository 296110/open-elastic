#!/usr/bin/env bash

set -e

function install_filebeat {
  local -r use_ssl="$1"
  local -r filebeat_version="$2"
  local -r module_filebeat_version="$3"
  local -r module_filebeat_branch="$4"
  local -r config_dir="$5"

  local -a args=(--module-name 'install-filebeat' '--repo' 'https://github.com/gruntwork-io/terraform-aws-elk' --tag "$module_filebeat_version" --branch "$module_filebeat_branch" --module-param "version=$filebeat_version")

  if [[ "$use_ssl" = true ]]; then
    echo "Installing Filebeat with SSL config: version: $module_filebeat_version"
    args+=(--module-param "config-file=$config_dir/filebeat-ssl.yml" --module-param 'ssl-config-dir=/tmp/ssl')

  else
    echo "Installing Filebeat without SSL config: version: $module_filebeat_version"
    args+=(--module-param "config-file=$config_dir/filebeat.yml")
  fi

  gruntwork-install "${args[@]}"
}

install_filebeat "$@"

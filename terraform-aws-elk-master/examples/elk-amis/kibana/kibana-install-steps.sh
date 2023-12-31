#!/usr/bin/env bash

set -e

function install_kibana {
  local -r use_ssl="$1"
  local -r module_kibana_version="$2"
  local -r module_kibana_branch="$3"

  if [[ "$use_ssl" = true ]]; then
    echo "Installing Kibana with SSL config: version: $module_kibana_version"
    gruntwork-install --module-name 'install-kibana' --repo 'https://github.com/gruntwork-io/terraform-aws-elk' --tag "$module_kibana_version" --branch "$module_kibana_branch" --module-param 'config-file=/tmp/config/kibana-ssl.yml' --module-param 'ssl-config-dir=/tmp/ssl'

  else
    echo "Installing Kibana without SSL config: version: $module_kibana_version"
    gruntwork-install --module-name 'install-kibana' --repo 'https://github.com/gruntwork-io/terraform-aws-elk' --tag "$module_kibana_version" --branch "$module_kibana_branch"

  fi
}

install_kibana "$@"
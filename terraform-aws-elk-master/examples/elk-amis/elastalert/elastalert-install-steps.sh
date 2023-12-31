#!/usr/bin/env bash

set -e

function install_elastalert {
  local -r use_ssl="$1"
  local -r module_elastalert_version="$2"
  local -r module_elastalert_branch="$3"
  local -r elastalert_version="$4"

  if [[ "$use_ssl" = true ]]; then
    echo "Installing ElastAlert with SSL config: version: $module_elastalert_version"
    gruntwork-install --module-name 'install-elastalert' --repo 'https://github.com/gruntwork-io/terraform-aws-elk' --tag "$module_elastalert_version" --branch "$module_elastalert_branch" --module-param 'config-file=/tmp/elastalert-config/config-ssl.yml' --module-param 'ssl-config-dir=/tmp/ssl' --module-param 'version='"$elastalert_version"

  else
    echo "Installing ElastAlert without SSL config: version: $module_elastalert_version"
    gruntwork-install --module-name 'install-elastalert' --repo 'https://github.com/gruntwork-io/terraform-aws-elk' --tag "$module_elastalert_version" --branch "$module_elastalert_branch" --module-param 'version='"$elastalert_version"

  fi
}

install_elastalert "$@"
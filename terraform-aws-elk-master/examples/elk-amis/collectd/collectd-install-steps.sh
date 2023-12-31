#!/usr/bin/env bash

set -e

function install_collectd {
  local -r use_ssl="$1"
  local -r module_collectd_version="$2"
  local -r module_collectd_branch="$3"
  local -r config_dir="$4"

  # NOTE: We shift each argument so that we can pass any extra parameters directly to the installer
  shift 4
  local -a extra_params=("$@")

  local -a args=(--module-name 'install-collectd' '--repo' 'https://github.com/gruntwork-io/terraform-aws-elk' --tag "$module_collectd_version" --branch "$module_collectd_branch")

  if [[ "$use_ssl" = true ]]; then
    echo "Installing Collectd with SSL config: version: $module_collectd_version"
    args+=(--module-param "config-file=$config_dir/collectd-ssl.conf" --module-param 'ssl-config-dir=/tmp/ssl')
  else
    echo "Installing Collectd without SSL config: version: $module_collectd_version"
    args+=(--module-param "config-file=$config_dir/collectd.conf")
  fi
  # Concatenate the two arrays: https://stackoverflow.com/a/31143930
  args+=("${extra_params[@]}")

  gruntwork-install "${args[@]}"
}

install_collectd "$@"

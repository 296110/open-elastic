#!/usr/bin/env bash

set -e

function install_logstash {
  local -r use_ssl="$1"
  local -r module_logstash_version="$2"
  local -r module_logstash_branch="$3"
  local -r logstash_version="$4"

  if [[ "$use_ssl" = true ]]; then
    echo "Installing Logstash with SSL config: version: $module_logstash_version"
    gruntwork-install --module-name 'install-logstash' --repo 'https://github.com/gruntwork-io/terraform-aws-elk' --tag "$module_logstash_version" --branch "$module_logstash_branch" --module-param 'version='"$logstash_version" --module-param 'config-file=/tmp/config/logstash-ssl.yml' --module-param 'pipeline-config-file=/tmp/config/pipeline-ssl.conf' --module-param 'plugin=logstash-input-cloudwatch_logs' --module-param 'ssl-config-dir=/tmp/ssl'

  else
    echo "Installing Logstash without SSL config: version: $module_logstash_version"
    gruntwork-install --module-name 'install-logstash' --repo 'https://github.com/gruntwork-io/terraform-aws-elk' --tag "$module_logstash_version" --branch "$module_logstash_branch" --module-param 'version='"$logstash_version" --module-param 'config-file=/tmp/config/logstash.yml' --module-param 'pipeline-config-file=/tmp/config/pipeline.conf' --module-param 'plugin=logstash-input-cloudwatch_logs'

  fi
}

install_logstash "$@"
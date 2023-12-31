#!/usr/bin/env bash

set -e

function install_elasticsearch {
  local -r use_ssl="$1"
  local -r module_elasticsearch_version="$2"
  local -r module_elasticsearch_branch="$3"

  if [[ "$use_ssl" = true ]]; then
    echo "Installing Elasticsearch with SSL config: version: $module_elasticsearch_version"
    gruntwork-install \
      --module-name 'install-elasticsearch' \
      --repo 'https://github.com/gruntwork-io/terraform-aws-elk' \
      --tag "$module_elasticsearch_version" \
      --branch "$module_elasticsearch_branch" \
      --module-param 'version='"$module_elasticsearch_version" \
      --module-param 'config-file=/tmp/config/elasticsearch-ssl.yml' \
      --module-param 'plugin=discovery-ec2' \
      --module-param 'plugin=repository-s3' \
      --module-param 'plugin=file:///tmp/plugins/readonlyrest-1.37.0_es6.8.21.zip' \
      --module-param 'plugin-config-dir=/tmp/readonlyrest-config' \
      --module-param 'ssl-config-dir=/tmp/ssl'
  else
    echo "Installing Elasticsearch without SSL config: version: $module_elasticsearch_version"
    gruntwork-install \
      --module-name 'install-elasticsearch' \
      --repo 'https://github.com/gruntwork-io/terraform-aws-elk' \
      --tag "$module_elasticsearch_version" \
      --branch "$module_elasticsearch_branch" \
      --module-param 'version='"$module_elasticsearch_version" \
      --module-param 'config-file=/tmp/config/elasticsearch.yml' \
      --module-param 'plugin=discovery-ec2' \
      --module-param 'plugin=repository-s3'
  fi
}

install_elasticsearch "$@"

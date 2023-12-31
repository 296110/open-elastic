#!/usr/bin/env bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

readonly DEFAULT_ELASTICSEARCH_INSTALL_DIR="/usr/share/elasticsearch"

function log {
  >&2 echo -e "$@"
}

function run {
  local -r cluster_name="$1"
  local -r network_host="$2"
  local -r jvm_xms="$3"
  local -r jvm_xmx="$4"
  local -r min_master_nodes="$5"
  local -r aws_region="$6"
  local -r keystore_file="$7"
  local -r keystore_pass="$8"
  local -r key_pass="$9"
  local -r key_alias="$${10}"
  local -r use_ssl="$${11}"

  local args=()

  args+=("--auto-fill" "<__CLUSTER_NAME__>=$cluster_name")
  args+=("--auto-fill" "<__NETWORK_HOST__>=$network_host")
  args+=("--auto-fill" "<__MIN_MASTER_NODES__>=$min_master_nodes")
  args+=("--auto-fill" "<__EC2_SERVER_GROUP_NAME__>=$cluster_name")
  args+=("--auto-fill-endpoint" "<__EC2_ENDPOINT__>=$aws_region")
  args+=("--auto-fill-jvm" "<__XMS__>=$jvm_xms")
  args+=("--auto-fill-jvm" "<__XMX__>=$jvm_xmx")

  if [[ "$use_ssl" = true ]]; then
    log "Using SSL and passing extra SSL parameters to run script. This includes authentication parameters for elasticsearch users."
    log "Going to keystore called: $keystore_file"

    args+=("--auto-fill-ror" "<__KEYSTORE_FILE__>=$keystore_file")
    args+=("--auto-fill-ror" "<__KEYSTORE_PASS__>=$keystore_pass")
    args+=("--auto-fill-ror" "<__KEY_PASS__>=$key_pass")
    args+=("--auto-fill-ror" "<__KEY_ALIAS__>=$key_alias")

    # NOTE: The following is only necessary if you are planning on running logstash or kibana alongside the
    # Elasticsearch cluster. Refer to the readonlyrest.yml configuration for how to configure additional users.
    # For testing purposes, we use a predefined insecure password but in production, you will want to modify this to be
    # dynamically configured.
    # Credentials are:
    # - logstash = logstash:password
    # - kibana = kibana:password
    # MAINTAINERS NOTE: https://github.com/gruntwork-io/terraform-aws-elk/issues/109
    args+=("--auto-fill-ror" "<__LOGSTASH_PASS_SHA256__>=b245172ce120e559a7d9482a9c224e71c9e0ad7cbf1625ffe033ebc18c3035e6")
    args+=("--auto-fill-ror" "<__KIBANA_PASS_SHA256__>=509506a876a84d2a4ee7d6354c75ba7c1543e60eff2b9c4007350bce5e29c561")
  fi

  "$DEFAULT_ELASTICSEARCH_INSTALL_DIR/bin/run-elasticsearch" "$${args[@]}"
}

# The variables below are filled in via Terraform interpolation
echo "Running with param cluster_name: ${cluster_name} and host: ${network_host}"
run \
    "${cluster_name}" \
    "${network_host}" \
    "${jvm_xms}" \
    "${jvm_xmx}" \
    "${min_master_nodes}" \
    "${aws_region}" \
    "${keystore_file}" \
    "${keystore_pass}" \
    "${key_pass}" \
    "${key_alias}" \
    "${use_ssl}"

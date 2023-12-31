#!/usr/bin/env bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

readonly DEFAULT_ELASTICSEARCH_INSTALL_DIR="/usr/share/elasticsearch"

function run {
  local -r cluster_name="$1"
  local -r network_host="$2"
  local -r jvm_xms="$3"
  local -r jvm_xmx="$4"
  local -r ping_unicast_hosts="$5"
  local -r min_master_nodes="$6"
  local -r keystore_file="$7"
  local -r keystore_pass="$8"
  local -r key_pass="$9"
  local -r key_alias="${10}"

  "$DEFAULT_ELASTICSEARCH_INSTALL_DIR/bin/run-elasticsearch" \
   --auto-fill "<__CLUSTER_NAME__>=$cluster_name" \
   --auto-fill "<__NETWORK_HOST__>=$network_host" \
   --auto-fill "<__PING_UNICAST_HOSTS__>=$ping_unicast_hosts" \
   --auto-fill "<__MIN_MASTER_NODES__>=$min_master_nodes" \
   --auto-fill-jvm "<__XMS__>=$jvm_xms" \
   --auto-fill-jvm "<__XMX__>=$jvm_xmx" \
   --auto-fill-ror "<__KEYSTORE_FILE__>=$keystore_file" \
   --auto-fill-ror "<__KEYSTORE_PASS__>=$keystore_pass" \
   --auto-fill-ror "<__KEY_PASS__>=$key_pass" \
   --auto-fill-ror "<__KEY_ALIAS__>=$key_alias"
}

# The variables below are filled in via Terraform interpolation
echo "Running with param cluster_name: ${cluster_name} and host: ${network_host}"
run \
    "${cluster_name}" \
    "${network_host}" \
    "${jvm_xms}" \
    "${jvm_xmx}" \
    "${ping_unicast_hosts}" \
    "${min_master_nodes}" \
    "${keystore_file}" \
    "${keystore_pass}" \
    "${key_pass}" \
    "${key_alias}"

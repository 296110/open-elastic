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

  "$DEFAULT_ELASTICSEARCH_INSTALL_DIR/bin/run-elasticsearch" \
   --auto-fill "<__CLUSTER_NAME__>=$cluster_name" \
   --auto-fill "<__NETWORK_HOST__>=$network_host" \
   --auto-fill "<__PING_UNICAST_HOSTS__>=$ping_unicast_hosts" \
   --auto-fill "<__MIN_MASTER_NODES__>=$min_master_nodes" \
   --auto-fill-jvm "<__XMS__>=$jvm_xms" \
   --auto-fill-jvm "<__XMX__>=$jvm_xmx"
}

# The variables below are filled in via Terraform interpolation
echo "Running with param cluster_name: ${cluster_name} and host: ${network_host}"
run \
    "${cluster_name}" \
    "${network_host}" \
    "${jvm_xms}" \
    "${jvm_xmx}" \
    "${ping_unicast_hosts}" \
    "${min_master_nodes}"

#!/usr/bin/env bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

readonly DEFAULT_ELASTICSEARCH_INSTALL_DIR="/usr/share/elasticsearch"
readonly DEFAULT_KIBANA_INSTALL_DIR="/usr/share/kibana"
readonly DEFAULT_KIBANA_UI_PORT=5601
readonly DEFAULT_LOGSTASH_INSTALL_DIR="/usr/share/logstash"

function run_elasticsearch {
  local -r cluster_name="$1"
  local -r network_host="$2"
  local -r jvm_xms="$3"
  local -r jvm_xmx="$4"
  local -r min_master_nodes="$5"
  local -r aws_region="$6"

  "$DEFAULT_ELASTICSEARCH_INSTALL_DIR/bin/run-elasticsearch" \
   --auto-fill "<__CLUSTER_NAME__>=$cluster_name" \
   --auto-fill "<__NETWORK_HOST__>=$network_host" \
   --auto-fill "<__MIN_MASTER_NODES__>=$min_master_nodes" \
   --auto-fill "<__EC2_SERVER_GROUP_NAME__>=$cluster_name" \
   --auto-fill-endpoint "<__EC2_ENDPOINT__>=$aws_region" \
   --auto-fill-jvm "<__XMS__>=$jvm_xms" \
   --auto-fill-jvm "<__XMX__>=$jvm_xmx"
}

function run_filebeat {
  local -r log_path="$1"
  local -r tag="$2"
  local -r port="$3"
  local -r region="$4"

  # Create sample log file
cat << EOF > "${log_path}"
${log_content}
EOF

  # Update the sample log file to be writable by all users
  # This is used for automated testing and is NOT recommended
  # in a production setting.
  sudo chmod 766 "${log_path}"

  local args=()
  args+=("--auto-fill" "<__APPLICATION_LOG_PATH__>=$log_path")
  args+=("--tag" "$tag")
  args+=("--port" "$port")
  args+=("--aws-region" "$region")

  run-filebeat $${args[@]}
}

function run_kibana {
  local -r server_name="$1"
  local kibana_ui_port="$2"
  local -r elasticsearch_url="$3"

  local -r kibana_ui_port="$${2:-$DEFAULT_KIBANA_UI_PORT}"

  "$DEFAULT_KIBANA_INSTALL_DIR/bin/run-kibana" \
   --auto-fill "<__SERVER_NAME__>=$server_name" \
   --auto-fill "<__KIBANA_UI_PORT__>=$kibana_ui_port" \
   --auto-fill "<__ELASTICSEARCH_URL__>=$elasticsearch_url"
}

function run_logstash {
  local -r beats_port="$1"
  local -r collectd_port="$2"
  local -r elasticsearch_host="$3"
  local -r elasticsearch_port="$4"
  local -r bucket="$5"
  local -r region="$6"
  local -r output_path="$7"
  local -r log_group="$8"
  local -r jvm_xms="$9"
  local -r jvm_xmx="$${10}"

  # Create the destination log file and setup permissions for Logstash
  sudo touch "$output_path"
  sudo chown logstash:logstash "$output_path"
  sudo chmod 0644 "$output_path"

  "$DEFAULT_LOGSTASH_INSTALL_DIR/bin/run-logstash" \
   --auto-fill-pipeline "<__BEATS_PORT__>=$beats_port" \
   --auto-fill-pipeline "<__COLLECTD_PORT__>=$collectd_port" \
   --auto-fill-pipeline "<__ELASTICSEARCH_HOST__>=$elasticsearch_host" \
   --auto-fill-pipeline "<__ELASTICSEARCH_PORT__>=$elasticsearch_port" \
   --auto-fill-pipeline "<__BUCKET__>=$bucket" \
   --auto-fill-pipeline "<__REGION__>=$region" \
   --auto-fill-pipeline "<__OUTPUT_PATH__>=$output_path" \
   --auto-fill-pipeline "<__LOG_GROUP__>=$log_group" \
   --auto-fill-jvm "<__XMS__>=$jvm_xms" \
   --auto-fill-jvm "<__XMX__>=$jvm_xmx"
}

function run_collectd {
  local -r logstash_url="$1"

  run-collectd \
   --auto-fill "<__LOGSTASH_URL__>=$logstash_url"
}

# The variables below are filled in via Terraform interpolation
echo "Running with param cluster_name: ${cluster_name} and host: ${network_host}"
run_elasticsearch \
    "${cluster_name}" \
    "${network_host}" \
    "${jvm_xms}" \
    "${jvm_xmx}" \
    "${min_master_nodes}" \
    "${aws_region}"

run_filebeat \
  "${log_path}" \
  "${tag}" \
  "${port}" \
  "${region}"

run_kibana \
  "${server_name}" \
  "${kibana_ui_port}" \
  "${elasticsearch_url}"

run_logstash \
  "${beats_port}" \
  "${collectd_port}" \
  "${elasticsearch_host}" \
  "${elasticsearch_port}" \
  "${bucket}" \
  "${region}" \
  "${output_path}" \
  "${log_group}" \
  "${jvm_xms}" \
  "${jvm_xmx}"

run_collectd \
  "${logstash_url}"

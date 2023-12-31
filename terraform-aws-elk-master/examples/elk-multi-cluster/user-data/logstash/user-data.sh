#!/usr/bin/env bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

readonly DEFAULT_LOGSTASH_INSTALL_DIR="/usr/share/logstash"

function log {
  >&2 echo -e "$@"
}

function get_from_secrets_manager {
  local -r arn="$1"

  local region
  region="$(curl --silent --location --fail http://169.254.169.254/latest/dynamic/instance-identity/document | jq -r .region)"

  log "Retrieving secret from Secrets Manager arn $arn in region $region"

  aws secretsmanager get-secret-value \
    --region "$region" \
    --secret-id "$arn" \
    --query 'SecretString' \
    --output text
}

function run {
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
  local -r ca_auth_path="$${11}"
  local -r cert_pem_path="$${12}"
  local -r cert_key_p8_path="$${13}"
  local -r keystore_file="$${14}"
  local -r keystore_pass="$${15}"
  local -r use_ssl="$${16}"
  local -r elasticsearch_password_for_logstash_secrets_manager_arn="$${17}"

  local args=()

  # Create the destination log file and setup permissions for Logstash
  sudo touch "$output_path"
  sudo chown logstash:logstash "$output_path"
  sudo chmod 0644 "$output_path"

  args+=("--auto-fill-pipeline" "<__BEATS_PORT__>=$beats_port")
  args+=("--auto-fill-pipeline" "<__COLLECTD_PORT__>=$collectd_port")
  args+=("--auto-fill-pipeline" "<__ELASTICSEARCH_HOST__>=$elasticsearch_host")
  args+=("--auto-fill-pipeline" "<__ELASTICSEARCH_PORT__>=$elasticsearch_port")
  args+=("--auto-fill-pipeline" "<__BUCKET__>=$bucket")
  args+=("--auto-fill-pipeline" "<__REGION__>=$region")
  args+=("--auto-fill-pipeline" "<__OUTPUT_PATH__>=$output_path")
  args+=("--auto-fill-pipeline" "<__LOG_GROUP__>=$log_group")
  args+=("--auto-fill-jvm" "<__XMS__>=$jvm_xms")
  args+=("--auto-fill-jvm" "<__XMX__>=$jvm_xmx")

  if [[ "$use_ssl" = true ]]; then
    log "Using SSL and passing extra SSL parameters to run script. This includes authentication parameters for elasticsearch users."
    log "Going to use CA: $ca_auth_path"

    local elasticsearch_password
    elasticsearch_password="$(get_from_secrets_manager "$elasticsearch_password_for_logstash_secrets_manager_arn")"

    args+=("--auto-fill-pipeline" "<__CA_AUTH_PATH__>=$ca_auth_path")
    args+=("--auto-fill-pipeline" "<__CERT_PEM_PATH__>=$cert_pem_path")
    args+=("--auto-fill-pipeline" "<__CERT_KEY_P8_PATH__>=$cert_key_p8_path")
    args+=("--auto-fill-pipeline" "<__ES_CA_AUTH_PATH__>=$ca_auth_path")
    args+=("--auto-fill-pipeline" "<__KEYSTORE_FILE__>=$keystore_file")
    args+=("--auto-fill-pipeline" "<__KEYSTORE_PASS__>=$keystore_pass")
    args+=("--auto-fill-pipeline" "<__ELASTICSEARCH_PASS_FOR_LOGSTASH__>=$elasticsearch_password")
  fi

  "$DEFAULT_LOGSTASH_INSTALL_DIR/bin/run-logstash" "$${args[@]}"
}

# The variables below are filled in via Terraform interpolation

run \
  "${beats_port}" \
  "${collectd_port}" \
  "${elasticsearch_host}" \
  "${elasticsearch_port}" \
  "${bucket}" \
  "${region}" \
  "${output_path}" \
  "${log_group}" \
  "${jvm_xms}" \
  "${jvm_xmx}" \
  "${ca_auth_path}" \
  "${cert_pem_path}" \
  "${cert_key_p8_path}" \
  "${keystore_file}" \
  "${keystore_pass}" \
  "${use_ssl}" \
  "${elasticsearch_password_for_logstash_secrets_manager_arn}"

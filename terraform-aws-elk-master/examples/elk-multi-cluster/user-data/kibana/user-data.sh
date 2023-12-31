#!/usr/bin/env bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

readonly DEFAULT_KIBANA_INSTALL_DIR="/usr/share/kibana"
readonly DEFAULT_KIBANA_UI_PORT=5601

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
  local -r server_name="$1"
  local kibana_ui_port="$2"
  local -r elasticsearch_url="$3"
  local -r ca_auth_path="$4"
  local -r cert_pem_path="$5"
  local -r cert_key_path="$6"
  local -r use_ssl="$7"
  local -r elasticsearch_password_for_kibana_secrets_manager_arn="$8"

  local -r kibana_ui_port="$${2:-$DEFAULT_KIBANA_UI_PORT}"

  local args=()

  args+=("--auto-fill" "<__SERVER_NAME__>=$server_name")
  args+=("--auto-fill" "<__KIBANA_UI_PORT__>=$kibana_ui_port")
  args+=("--auto-fill" "<__ELASTICSEARCH_URL__>=$elasticsearch_url")

  if [[ "$use_ssl" = true ]]; then
    log "Using SSL and passing extra SSL parameters to run script. This includes authentication parameters for elasticsearch users."
    log "Going to use CA: $ca_auth_path"

    local elasticsearch_password
    elasticsearch_password="$(get_from_secrets_manager "$elasticsearch_password_for_kibana_secrets_manager_arn")"

    args+=("--auto-fill" "<__CA_AUTH_PATH__>=$ca_auth_path")
    args+=("--auto-fill" "<__CERT_PEM_PATH__>=$cert_pem_path")
    args+=("--auto-fill" "<__CERT_KEY_PATH__>=$cert_key_path")
    args+=("--auto-fill" "<__ES_CERT_PEM_PATH__>=$cert_pem_path")
    args+=("--auto-fill" "<__ES_CERT_KEY_PATH__>=$cert_key_path")
    args+=("--auto-fill" "<__ELASTICSEARCH_PASS_FOR_KIBANA__>=$elasticsearch_password")
  fi

  "$DEFAULT_KIBANA_INSTALL_DIR/bin/run-kibana" "$${args[@]}"
}

# The variables below are filled in via Terraform interpolation
run \
  "${server_name}" \
  "${kibana_ui_port}" \
  "${elasticsearch_url}" \
  "${ca_auth_path}" \
  "${cert_pem_path}" \
  "${cert_key_path}" \
  "${use_ssl}" \
  "${elasticsearch_password_for_kibana_secrets_manager_arn}"

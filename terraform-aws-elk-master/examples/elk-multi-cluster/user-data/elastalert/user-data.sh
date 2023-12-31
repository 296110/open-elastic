#!/usr/bin/env bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

function run {
  local -r elasticsearch_url="$1"
  local -r elasticsearch_port="$2"
  local -r rules_folder_path="$3"
  local -r ca_auth_path="$4"
  local -r cert_pem_path="$5"
  local -r cert_key_path="$6"
  local -r use_ssl="$7"
  local -r sns_topic_arn="$8"
  local -r sns_topic_aws_region="$9"

  local args=()

  args+=("--auto-fill" "<__ES_HOST__>=$elasticsearch_url")
  args+=("--auto-fill" "<__ES_PORT__>=$elasticsearch_port")
  args+=("--auto-fill" "<__RULES_FOLDER_PATH__>=$rules_folder_path")

  args+=("--auto-fill-rule" "<__SNS_TOPIC_ARN__>=$sns_topic_arn")
  args+=("--auto-fill-rule" "<__SNS_TOPIC_AWS_REGION__>=$sns_topic_aws_region")

  if [[ "$use_ssl" = true ]]; then
    echo "Using SSL and passing extra SSL parameters to run script. Going to use CA: $ca_auth_path"
    args+=("--auto-fill" "<__CA_AUTH_PATH__>=$ca_auth_path")
    args+=("--auto-fill" "<__CERT_PEM_PATH__>=$cert_pem_path")
    args+=("--auto-fill" "<__CERT_KEY_PATH__>=$cert_key_path")
  fi

  "/usr/bin/run-elastalert" "$${args[@]}"
}

# The variables below are filled in via Terraform interpolation
run \
  "${elasticsearch_url}" \
  "${elasticsearch_port}" \
  "${rules_folder_path}" \
  "${ca_auth_path}" \
  "${cert_pem_path}" \
  "${cert_key_path}" \
  "${use_ssl}" \
  "${sns_topic_arn}" \
  "${sns_topic_aws_region}"

#!/usr/bin/env bash

set -e

# Send the log output from this script to user-data.log, syslog, and the console
# From: https://alestic.com/2010/12/ec2-user-data-output/
exec > >(tee /var/log/user-data.log|logger -t user-data -s 2>/dev/console) 2>&1

function run_filebeat {
  local -r log_path="$1"
  local -r ca_auth_path="$2"
  local -r cert_pem_path="$3"
  local -r cert_key_path="$4"
  local -r use_ssl="$5"
  local -r tag="$6"
  local -r port="$7"
  local -r region="$8"

  local -a args=()

  args+=("--auto-fill" "<__APPLICATION_LOG_PATH__>=$log_path")
  args+=("--tag" "$tag")
  args+=("--port" "$port")
  args+=("--aws-region" "$region")

  if [[ "$use_ssl" = true ]]; then
    echo "Using SSL and passing extra SSL parameters to run script. Going to use CA: $ca_auth_path"
    args+=("--auto-fill" "<__CA_AUTH_PATH__>=$ca_auth_path")
    args+=("--auto-fill" "<__CERT_PEM_PATH__>=$cert_pem_path")
    args+=("--auto-fill" "<__CERT_KEY_PATH__>=$cert_key_path")
  fi

  # Create sample log file
cat << EOF > "${log_path}"
${log_content}
EOF

  # Update the sample log file to be writable by all users
  # This is used for automated testing and is NOT recommended
  # in a production setting.
  sudo chmod 766 "${log_path}"

  run-filebeat "$${args[@]}"
}

function run_collectd {
  local -r logstash_url="$1"
  local -r ca_path="$2"
  local -r use_ssl="$3"

  local args=()

  args+=("--auto-fill" "<__LOGSTASH_URL__>=$logstash_url")

  if [[ "$use_ssl" = true ]]; then
    echo "Using SSL and passing extra SSL parameters to run script. Going to use CA Path: $ca_path"
    args+=("--auto-fill" "<__CA_FILE__>=$ca_path")
  fi

  run-collectd "$${args[@]}"
}

# The variables below are filled in via Terraform interpolation
run_filebeat \
  "${log_path}" \
  "${ca_auth_path}" \
  "${cert_pem_path}" \
  "${cert_key_path}" \
  "${use_ssl}" \
  "${tag}" \
  "${port}" \
  "${region}"

# The variables below are filled in via Terraform interpolation
run_collectd \
  "${logstash_url}" \
  "${ca_path}" \
  "${use_ssl}"

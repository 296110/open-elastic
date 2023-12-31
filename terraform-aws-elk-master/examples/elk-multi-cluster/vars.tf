# ---------------------------------------------------------------------------------------------------------------------
# REQUIRED PARAMETERS
# These variables are expected to be passed in by the operator
# ---------------------------------------------------------------------------------------------------------------------

variable "elastalert_ami_id" {
  description = "The AMI which has ElastAlert installed"
  type        = string
}

variable "elasticsearch_ami_id" {
  description = "The AMI which has Elasticsearch installed"
  type        = string
}

variable "logstash_ami_id" {
  description = "The AMI which has Logstash installed"
  type        = string
}

variable "app_server_ami_id" {
  description = "The AMI which has Filebeat and CollectD installed"
  type        = string
}

variable "kibana_ami_id" {
  description = "The AMI which has Kibana installed"
  type        = string
}

variable "aws_region" {
  description = "The AWS region in which all resources will be created"
  type        = string
}

variable "route53_zone_name" {
  description = "The domain name of the Route53 Hosted Zone we want to use to create an Alias record."
  type        = string
}

variable "route53_zone_id" {
  description = "The zone id of the Route53 Hosted Zone we want to use to create an Alias record."
  type        = string
}

variable "sns_topic_name" {
  description = "The name of the SNS topic that will be created"
  type        = string
}

# ---------------------------------------------------------------------------------------------------------------------
# OPTIONAL PARAMETERS
# These variables may optionally be passed in by the operator, but they have reasonable defaults.
# ---------------------------------------------------------------------------------------------------------------------

variable "elasticsearch_password_for_logstash_secrets_manager_arn" {
  description = "The ARN of a secrets manager entry containing the password to use for authenticating logstash requests to Elasticsearch. Only used if use_ssl = true, as authentication is handled by the readonlyrest plugin."
  type        = string
  default     = ""
}

variable "elasticsearch_password_for_kibana_secrets_manager_arn" {
  description = "The ARN of a secrets manager entry containing the password to use for authenticating kibana requests to Elasticsearch. Only used if use_ssl = true, as authentication is handled by the readonlyrest plugin."
  type        = string
  default     = ""
}

variable "elasticsearch_cluster_name" {
  description = "The name of the Elasticsearch cluster"
  type        = string
  default     = "ExampleESCluster"
}

variable "logstash_cluster_name" {
  description = "The name of the Logstash cluster"
  type        = string
  default     = "LogstashCluster"
}

variable "kibana_cluster_name" {
  description = "The name of the Kibana cluster"
  type        = string
  default     = "ExKibanaCluster"
}

variable "elasticsearch_cluster_size" {
  description = "The number of nodes in this Elasticsearch cluster."
  type        = number
  default     = 3
}

variable "logstash_cluster_size" {
  description = "The number of nodes in this Logstash cluster."
  type        = number
  default     = 1
}

variable "kibana_cluster_size" {
  description = "The number of nodes in this Kibana cluster."
  type        = number
  default     = 1
}

variable "kibana_ui_port" {
  description = "This is the port that is used to access kibana UI"
  type        = number
  default     = 5601
}

variable "filebeat_port" {
  description = "The port on which Filebeat will communicate with the Logstash cluster"
  type        = number
  default     = 5044
}

variable "collectd_port" {
  description = "The port on which CollectD will communicate with the Logstash cluster"
  type        = number
  default     = 8080
}

variable "cloudtrail_dest_log_path" {
  description = "The path to the destination log file that Logstash will pipe cloudtrail logs to"
  type        = string
  default     = "/var/log/destination.log"
}

variable "key_name" {
  description = "Optional name of key to be used to ssh into the cluster members"
  type        = string
  default     = null
}

variable "elastalert_instance_type" {
  description = "The type of EC2 Instance to run for ElastAlert (e.g. t2.small)."
  type        = string
  default     = "t2.small"
}

variable "elasticsearch_instance_type" {
  description = "The type of EC2 Instance to run for Elasticsearch (e.g. t2.small)."
  type        = string
  default     = "t2.large"
}

variable "elasticsearch_api_port" {
  description = "The port on which Elasticsearch API should be accessed."
  type        = number
  default     = 9200
}

variable "kibana_instance_type" {
  description = "The type of EC2 Instance to run for Kibana (e.g. t2.small)."
  type        = string
  default     = "t2.small"
}

variable "logstash_instance_type" {
  description = "The type of EC2 Instance to run for Logstash (e.g. t2.small)."
  type        = string
  default     = "t2.large"
}

variable "app_server_instance_type" {
  description = "The type of EC2 Instance to run for Filebeat (e.g. t2.small)."
  type        = string
  default     = "t2.small"
}

variable "app_server_name" {
  description = "The Name for the app server instance"
  type        = string
  default     = "elk-app-server"
}

variable "filebeat_log_path" {
  description = "Path to the log file that will be watched by Filebeat"
  type        = string
  default     = "/var/log/source.log"
}

variable "use_ssl" {
  description = "Whether or not we want our Elasticsearch instance to use SSL encryption. If this is set to `true` don't forget to also set"
  type        = bool
  default     = false
}

variable "java_keystore_filename" {
  description = "The filename of the Java Keystore that will be on your AMI. Please provide this value if you are using SSL encryption"
  type        = string
  default     = ""
}

variable "java_keystore_certificate_password" {
  description = "The password of SSL certificate inside of the Java Keystore. Please provide this value if you are using SSL encryption"
  type        = string
  default     = ""
}

variable "java_keystore_password" {
  description = "The password of the Java Keystore. Please provide this value if you are using SSL encryption"
  type        = string
  default     = ""
}

variable "java_keystore_cert_alias" {
  description = "The alias that you gave to your certificate when you generated it and imported it into your Java Keystore. Please provide this value if you are using SSL encryption"
  type        = string
  default     = ""
}

variable "logstash_keystore_path" {
  description = "The path to the java keystore file in the Logstash AMI"
  type        = string
  default     = ""
}

variable "logstash_ca_auth_path" {
  description = "The path to the certificate authority in the Logstash AMI"
  type        = string
  default     = ""
}

variable "logstash_cert_pem_path" {
  description = "The path to the PEM encoded certificate in the Logstash AMI"
  type        = string
  default     = ""
}

variable "logstash_key_p8_path" {
  description = "The path to the PC8 encoded certificate key in the Logstash AMI"
  type        = string
  default     = ""
}

variable "kibana_ca_auth_path" {
  description = "The path to the certificate authority in the Kibana AMI"
  type        = string
  default     = ""
}

variable "kibana_cert_pem_path" {
  description = "The path to the PEM encoded certificate in the Kibana AMI"
  type        = string
  default     = ""
}

variable "kibana_cert_key_path" {
  description = "The path to the  certificate key in the Kibana AMI"
  type        = string
  default     = ""
}

variable "filebeat_ca_auth_path" {
  description = "The path to the certificate authority in the Filebeat AMI"
  type        = string
  default     = ""
}

variable "filebeat_cert_pem_path" {
  description = "The path to the PEM encoded certificate in the Filebeat AMI"
  type        = string
  default     = ""
}

variable "filebeat_cert_key_path" {
  description = "The path to the certificate key in the Filebeat AMI"
  type        = string
  default     = ""
}

variable "elastalert_ca_auth_path" {
  description = "The path to the certificate authority in the Elastalert AMI"
  type        = string
  default     = ""
}

variable "elastalert_cert_pem_path" {
  description = "The path to the PEM encoded certificate in the Elastalert AMI"
  type        = string
  default     = ""
}

variable "elastalert_cert_key_path" {
  description = "The path to the certificate key in the Elastalert AMI"
  type        = string
  default     = ""
}

variable "collectd_ca_path" {
  description = "The path to the certificate file in the CollectD AMI"
  type        = string
  default     = ""
}

variable "subdomain_name" {
  description = "The subdomain name to use in this example. This is the part of the URL that will go before the actual domain name. For example: http://elk.gruntwork-sandbox.com. 'elk' is the subdomain name here."
  type        = string
  default     = "elk"
}

variable "alb_name" {
  description = "The name for the ALB. This is used for namespacing."
  type        = string
  default     = "elk-alb"
}

variable "alb_target_group_protocol" {
  description = "The protocol for the Kibana ALB target group. Either HTTP or HTTPS depending on whether SSL is enabled."
  type        = string
  default     = "HTTP"
}

variable "ssl_policy" {
  description = "The aws predefined policy for alb. Only used when SSL is enabled. A List of policies can be found here: https://docs.aws.amazon.com/elasticloadbalancing/latest/application/create-https-listener.html#describe-ssl-policies"
  type        = string
  default     = "ELBSecurityPolicy-2016-08"
}

variable "sns_topic_display_name" {
  description = "The display name of the SNS topic. NOTE: Maximum length is 10 characters."
  type        = string
  default     = ""
}

variable "allow_publish_accounts" {
  description = "A list of IAM ARNs that will be given the rights to publish to the SNS topic."
  type        = list(string)
  default     = []

  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:role/jenkins"
  # ]
}

variable "allow_subscribe_accounts" {
  description = "A list of IAM ARNs that will be given the rights to subscribe to the SNS topic."
  type        = list(string)
  default     = []

  # Example:
  # default = [
  #   "arn:aws:iam::123445678910:role/jenkins"
  # ]
}

variable "allow_subscribe_protocols" {
  description = ""
  type        = list(string)

  default = [
    "http",
    "https",
    "email",
    "email-json",
    "sms",
    "sqs",
    "application",
    "lambda",
  ]
}

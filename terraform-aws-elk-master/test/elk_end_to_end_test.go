package test

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
	"github.com/stretchr/testify/require"
)

const CERT_INFO_PATH = ".test-data/CERT.json"
const URL_INFO_PATH = ".test-data/URL.json"

func TestELKEndToEnd(t *testing.T) {
	t.Parallel()

	gitHubToken := os.Getenv("GITHUB_OAUTH_TOKEN")
	require.NotEmpty(t, gitHubToken, "You must set the GITHUB_OAUTH_TOKEN environment variables for the Packer builds in this test to work!")

	// For convenience - uncomment these as well as the "os" import
	// when doing local testing if you need to skip any sections.
	// os.Setenv("SKIP_", "true")
	// os.Setenv("TERRATEST_REGION", "us-east-1")
	// os.Setenv("SKIP_create_secrets_manager_entries", "true")
	// os.Setenv("SKIP_generate_ssl_certs", "true")
	// os.Setenv("SKIP_setup_ami", "true")
	// os.Setenv("SKIP_deploy_to_aws", "true")
	// os.Setenv("SKIP_validate", "true")
	// os.Setenv("SKIP_validate_collectd", "true")
	// os.Setenv("SKIP_validate_cloudtrail", "true")
	// os.Setenv("SKIP_validate_cloudwatch", "true")
	// os.Setenv("SKIP_validate_kibana", "true")
	// os.Setenv("SKIP_get_logs", "true")
	// os.Setenv("SKIP_teardown", "true")
	// os.Setenv("SKIP_remove_secrets_manager_entries", "true")

	//zoneName := "gruntwork-sandbox.com" // Use this with Sandbox
	zoneName := "gruntwork.in" // Use this with PhxDevops

	//zoneId := "Z2VWPXQ2IDW13E" //sandbox
	zoneId := "Z2AJ7S3R6G9UYJ" //phx-devops

	var testcases = []struct {
		testName                   string
		builderSuffix              string
		elasticsearchPort          int
		elasticsearchDiscoveryPort int
		kibanaUIPort               int
		useSsl                     bool
		keystoreFile               string
		keystorePass               string
		certKeyPass                string
		certAlias                  string
		protocol                   string
		logstashCaAuthPath         string
		logstashCertPemPath        string
		logstashKeyP8Path          string
		logstashKeyStorePath       string
		kibanaCaAuthPath           string
		kibanaCertPemPath          string
		kibanaCertKeyPath          string
		filebeatCaAuthPath         string
		filebeatCertPemPath        string
		filebeatCertKeyPath        string
		elastalertCaAuthPath       string
		elastalertCertPemPath      string
		elastalertCertKeyPath      string
		collectdCAPath             string
		checkerFunction            func(t *testing.T, messageToVerify string, webConsoleUrl string, keyStore *keystore, kibanaPass string)
		sleepDuration              int
	}{
		{
			"TestElasticsearchUbuntu1804",
			"ubuntu-18",
			9200,
			9300,
			5601,
			false,
			"",
			"",
			"",
			"",
			"http",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			validateGetHttp,
			0,
		},
		{
			"TestElasticsearchUbuntu2004",
			"ubuntu-20",
			9200,
			9300,
			5601,
			false,
			"",
			"",
			"",
			"",
			"http",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			"",
			validateGetHttp,
			0,
		},
		{
			"TestElasticsearchUbuntu2004SSL",
			"ubuntu-20",
			9200,
			9300,
			5601,
			true,
			"elk.server.keystore.jks",
			"password",
			"password",
			"localhost",
			"https",
			"/etc/logstash/caFile",
			"/etc/logstash/localhost.pem",
			"/etc/logstash/localhost.p8",
			"/etc/logstash/elk.server.keystore.jks",
			"/etc/kibana/caFile",
			"/etc/kibana/localhost.pem",
			"/etc/kibana/localhost.key",
			"/etc/filebeat/caFile",
			"/etc/filebeat/localhost.pem",
			"/etc/filebeat/localhost.key",
			"/etc/elastalert/caFile",
			"/etc/elastalert/localhost.pem",
			"/etc/elastalert/localhost.key",
			"/etc/collectd/caFile",
			validateGetHttps,
			3,
		},
	}

	for _, testCase := range testcases {
		// The following is necessary to make sure testCase's values don't
		// get updated due to concurrency within the scope of t.Run(..) below
		testCase := testCase

		t.Run(testCase.testName, func(t *testing.T) {
			t.Parallel()

			// This is terrible - but attempt to stagger the test cases to
			// avoid a concurrency issue
			time.Sleep(time.Duration(testCase.sleepDuration) * time.Second)

			examplesDir := test_structure.CopyTerraformFolderToTemp(t, "../", "examples")
			elkAmisDir := fmt.Sprintf("%s/elk-amis", examplesDir)

			elasticsearchPackerInfo := PackerInfo{
				builderName:  fmt.Sprintf("elasticsearch-ami-%s", testCase.builderSuffix),
				templatePath: fmt.Sprintf("%s/elasticsearch/elasticsearch.json", elkAmisDir),
			}
			logstashPackerInfo := PackerInfo{
				builderName:  fmt.Sprintf("logstash-ami-%s", testCase.builderSuffix),
				templatePath: fmt.Sprintf("%s/logstash/logstash.json", elkAmisDir),
			}
			appServerPackerInfo := PackerInfo{
				builderName:  fmt.Sprintf("app-server-ami-%s", testCase.builderSuffix),
				templatePath: fmt.Sprintf("%s/app-server/app-server.json", elkAmisDir),
			}
			kibanaPackerInfo := PackerInfo{
				builderName:  fmt.Sprintf("kibana-ami-%s", testCase.builderSuffix),
				templatePath: fmt.Sprintf("%s/kibana/kibana.json", elkAmisDir),
			}
			elastalertPackerInfo := PackerInfo{
				builderName:  fmt.Sprintf("elastalert-ami-%s", testCase.builderSuffix),
				templatePath: fmt.Sprintf("%s/elastalert/elastalert.json", elkAmisDir),
			}

			defer test_structure.RunTestStage(t, "remove_secrets_manager_entries", func() {
				awsRegion := test_structure.LoadString(t, examplesDir, "awsRegion")
				kibanaPassSecretsManagerARN := test_structure.LoadString(t, examplesDir, "kibanaPassSecretsManagerARN")
				logstashPassSecretsManagerARN := test_structure.LoadString(t, examplesDir, "logstashPassSecretsManagerARN")

				aws.DeleteSecret(t, awsRegion, kibanaPassSecretsManagerARN, true)
				aws.DeleteSecret(t, awsRegion, logstashPassSecretsManagerARN, true)
			})
			test_structure.RunTestStage(t, "create_secrets_manager_entries", func() {
				awsRegion := aws.GetRandomStableRegion(t, RegionsWithGruntworkINACM, nil)
				test_structure.SaveString(t, examplesDir, "awsRegion", awsRegion)
				uniqueID := random.UniqueId()
				test_structure.SaveString(t, examplesDir, "uniqueID", uniqueID)

				kibanaPass := random.UniqueId()
				test_structure.SaveString(t, examplesDir, "kibanaPass", kibanaPass)
				kibanaPassARN := aws.CreateSecretStringWithDefaultKey(
					t,
					awsRegion,
					fmt.Sprintf("Password for kibana in ELK All in one test %s", uniqueID),
					fmt.Sprintf("Kibana_%s", uniqueID),
					kibanaPass,
				)
				test_structure.SaveString(t, examplesDir, "kibanaPassSecretsManagerARN", kibanaPassARN)

				logstashPass := random.UniqueId()
				logstashPassARN := aws.CreateSecretStringWithDefaultKey(
					t,
					awsRegion,
					fmt.Sprintf("Password for logstash in ELK All in one test %s", uniqueID),
					fmt.Sprintf("Logstash_%s", uniqueID),
					logstashPass,
				)
				test_structure.SaveString(t, examplesDir, "logstashPassSecretsManagerARN", logstashPassARN)
			})

			defer test_structure.RunTestStage(t, "teardown", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				terraform.Destroy(t, terraformOptions)
			})

			defer test_structure.RunTestStage(t, "get_logs", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)
				if t.Failed() {
					snapshotESAndLogstashLogs(t, terraformOptions, keyPair)
				}
			})

			test_structure.RunTestStage(t, "generate_ssl_certs", func() {
				awsRegion := test_structure.LoadString(t, examplesDir, "awsRegion")
				uniqueID := test_structure.LoadString(t, examplesDir, "uniqueID")

				subdomainName := strings.ToLower(uniqueID)

				deploymentUrl := fmt.Sprintf("%s.%s", subdomainName, zoneName)
				urlInfo := &UrlInfo{Subdomain: subdomainName, ZoneName: zoneName}
				test_structure.SaveTestData(t, fmt.Sprintf("%s/%s", examplesDir, URL_INFO_PATH), urlInfo)

				tlsOutputDir := fmt.Sprintf("%s/elk-amis", examplesDir)
				generateKeystoreDir := fmt.Sprintf("%s/%s", examplesDir, GENERATE_KEYSTORE_SCRIPT_FOLDER)

				downloadGenerateKeystoreScript(t, generateKeystoreDir)
				tlsCert := createKeyStoreFiles(t, "elk", generateKeystoreDir, tlsOutputDir, deploymentUrl)
				certFile, keyFile, p8KeyFile := exportCertAndKeyFromJks(t, tlsCert, "localhost", fmt.Sprintf("%s/ssl", tlsOutputDir), fmt.Sprintf("%s/ssl/keystore.p12", tlsOutputDir))

				tlsCert.CertFile = certFile
				tlsCert.KeyFile = keyFile
				tlsCert.P8KeyFile = p8KeyFile

				test_structure.SaveTestData(t, fmt.Sprintf("%s/%s", examplesDir, CERT_INFO_PATH), tlsCert)

				keyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, urlInfo.Subdomain)
				test_structure.SaveEc2KeyPair(t, examplesDir, keyPair)
			})

			test_structure.RunTestStage(t, "setup_ami", func() {
				awsRegion := test_structure.LoadString(t, examplesDir, "awsRegion")

				var tlsCert keystore
				test_structure.LoadTestData(t, fmt.Sprintf("%s/%s", examplesDir, CERT_INFO_PATH), &tlsCert)

				var urlInfo UrlInfo
				test_structure.LoadTestData(t, fmt.Sprintf("%s/%s", examplesDir, URL_INFO_PATH), &urlInfo)

				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)

				elkAmis := buildAllAmis(t,
					awsRegion,
					&elasticsearchPackerInfo,
					&logstashPackerInfo,
					&appServerPackerInfo,
					&kibanaPackerInfo,
					&elastalertPackerInfo,
					testCase.useSsl,
				)

				kibanaClusterName := fmt.Sprintf("kibana-%s", urlInfo.Subdomain)
				elasticsearchClusterName := fmt.Sprintf("es-cluster-%s", urlInfo.Subdomain)
				logstashClusterName := fmt.Sprintf("logstash-%s", urlInfo.Subdomain)
				albName := fmt.Sprintf("alb-%s", urlInfo.Subdomain)
				snsTopicName := fmt.Sprintf("sns-%s", urlInfo.Subdomain)

				largeInstanceType := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.large", "t3.large"})
				smallInstanceType := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.small", "t3.small"})
				kibanaPassSecretsManagerARN := test_structure.LoadString(t, examplesDir, "kibanaPassSecretsManagerARN")
				logstashPassSecretsManagerARN := test_structure.LoadString(t, examplesDir, "logstashPassSecretsManagerARN")
				terraformOptions := &terraform.Options{
					// The path to where your Terraform code is located
					TerraformDir: fmt.Sprintf("%s/elk-multi-cluster", examplesDir),
					Vars: map[string]interface{}{
						"aws_region":           awsRegion,
						"kibana_cluster_name":  kibanaClusterName,
						"kibana_ami_id":        elkAmis.KibanaAmi,
						"kibana_ui_port":       testCase.kibanaUIPort,
						"kibana_instance_type": smallInstanceType,

						"elasticsearch_cluster_name":  elasticsearchClusterName,
						"elasticsearch_ami_id":        elkAmis.ElasticsearchAmi,
						"elasticsearch_instance_type": largeInstanceType,

						"logstash_ami_id":        elkAmis.LogstashAmi,
						"logstash_instance_type": largeInstanceType,
						"logstash_cluster_name":  logstashClusterName,

						"app_server_ami_id":        elkAmis.AppServerAmi,
						"app_server_name":          fmt.Sprintf("elk-appserver-%s", urlInfo.Subdomain),
						"app_server_instance_type": smallInstanceType,
						"filebeat_log_path":        "/var/log/source.log",
						"key_name":                 keyPair.Name,

						"subdomain_name":            urlInfo.Subdomain,
						"route53_zone_id":           zoneId,
						"route53_zone_name":         zoneName,
						"use_ssl":                   strconv.FormatBool(testCase.useSsl),
						"alb_name":                  albName,
						"alb_target_group_protocol": strings.ToUpper(testCase.protocol),

						"elastalert_ami_id":        elkAmis.ElastAlertAmi,
						"elastalert_instance_type": smallInstanceType,
						"sns_topic_name":           snsTopicName,
					},
				}

				if testCase.useSsl {
					terraformOptions.Vars["ssl_policy"] = "ELBSecurityPolicy-2015-05"

					terraformOptions.Vars["java_keystore_filename"] = testCase.keystoreFile
					terraformOptions.Vars["java_keystore_password"] = testCase.keystorePass
					terraformOptions.Vars["java_keystore_certificate_password"] = testCase.certKeyPass
					terraformOptions.Vars["java_keystore_cert_alias"] = testCase.certAlias

					terraformOptions.Vars["logstash_keystore_path"] = testCase.logstashKeyStorePath
					terraformOptions.Vars["logstash_ca_auth_path"] = testCase.logstashCaAuthPath
					terraformOptions.Vars["logstash_cert_pem_path"] = testCase.logstashCertPemPath
					terraformOptions.Vars["logstash_key_p8_path"] = testCase.logstashKeyP8Path
					terraformOptions.Vars["elasticsearch_password_for_logstash_secrets_manager_arn"] = logstashPassSecretsManagerARN

					terraformOptions.Vars["kibana_ca_auth_path"] = testCase.kibanaCaAuthPath
					terraformOptions.Vars["kibana_cert_pem_path"] = testCase.kibanaCertPemPath
					terraformOptions.Vars["kibana_cert_key_path"] = testCase.kibanaCertKeyPath
					terraformOptions.Vars["elasticsearch_password_for_kibana_secrets_manager_arn"] = kibanaPassSecretsManagerARN

					terraformOptions.Vars["filebeat_ca_auth_path"] = testCase.filebeatCaAuthPath
					terraformOptions.Vars["filebeat_cert_pem_path"] = testCase.filebeatCertPemPath
					terraformOptions.Vars["filebeat_cert_key_path"] = testCase.filebeatCertKeyPath

					terraformOptions.Vars["elastalert_ca_auth_path"] = testCase.elastalertCaAuthPath
					terraformOptions.Vars["elastalert_cert_pem_path"] = testCase.elastalertCertPemPath
					terraformOptions.Vars["elastalert_cert_key_path"] = testCase.elastalertCertKeyPath

					terraformOptions.Vars["collectd_ca_path"] = testCase.collectdCAPath
				}

				test_structure.SaveTerraformOptions(t, examplesDir, terraformOptions)
			})

			test_structure.RunTestStage(t, "deploy_to_aws", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)

				terraform.InitAndApply(t, terraformOptions)
			})

			test_structure.RunTestStage(t, "validate", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				ip := terraform.Output(t, terraformOptions, "app_server_ip")
				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)

				var urlInfo UrlInfo
				test_structure.LoadTestData(t, fmt.Sprintf("%s/%s", examplesDir, URL_INFO_PATH), &urlInfo)

				var tlsCert keystore
				test_structure.LoadTestData(t, fmt.Sprintf("%s/%s", examplesDir, CERT_INFO_PATH), &tlsCert)

				host := ssh.Host{
					Hostname:    ip,
					SshUserName: "ubuntu",
					SshKeyPair:  keyPair.KeyPair,
				}

				randomMessage := writeAppServerLog(t, host, terraformOptions.Vars["filebeat_log_path"].(string))

				albUrl := terraform.OutputRequired(t, terraformOptions, "alb_url")
				elasticsearchUrl := fmt.Sprintf("%s:%d", albUrl, testCase.elasticsearchPort)
				queryUrl := fmt.Sprintf("%s/_all/_search?q=message:%s", elasticsearchUrl, randomMessage)

				kibanaPass := test_structure.LoadString(t, examplesDir, "kibanaPass")
				testCase.checkerFunction(t, randomMessage, queryUrl, &tlsCert, kibanaPass)
			})

			test_structure.RunTestStage(t, "validate_collectd", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)

				asgName := terraform.OutputList(t, terraformOptions, "logstash_server_asg_names")[0]
				publicInstanceIP := getIPForInstanceInAsg(t, asgName, terraformOptions)
				collectdServerIP := terraform.Output(t, terraformOptions, "app_server_ip")

				checkLogstashOutputLog(t, publicInstanceIP, "ubuntu", *keyPair, LogstashFileOutputPath, fmt.Sprintf("\"x_forwarded_for\":\"%s\"", collectdServerIP))
			})

			test_structure.RunTestStage(t, "validate_cloudwatch", func() {
				awsRegion := test_structure.LoadString(t, examplesDir, "awsRegion")
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)

				logGroup := terraform.Output(t, terraformOptions, "log_group")
				logContent := "This is a log line_cloudwatch"

				writeContentToLogStream(t, logGroup, logContent, awsRegion)

				asgName := terraform.OutputList(t, terraformOptions, "logstash_server_asg_names")[0]
				publicInstanceIP := getIPForInstanceInAsg(t, asgName, terraformOptions)

				checkLogstashOutputLog(t, publicInstanceIP, "ubuntu", *keyPair, LogstashFileOutputPath, fmt.Sprintf("\"message\":\"%s\"", logContent))
			})

			test_structure.RunTestStage(t, "validate_cloudtrail", func() {
				awsRegion := test_structure.LoadString(t, examplesDir, "awsRegion")
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)

				logContent := "This is a log line_cloudtrail"

				bucket := terraform.Output(t, terraformOptions, "bucket")
				key := writeContentToS3Bucket(t, bucket, logContent, awsRegion)

				asgName := terraform.OutputList(t, terraformOptions, "logstash_server_asg_names")[0]
				publicInstanceIP := getIPForInstanceInAsg(t, asgName, terraformOptions)

				checkLogstashOutputLog(t, publicInstanceIP, "ubuntu", *keyPair, LogstashFileOutputPath, fmt.Sprintf("\"message\":\"%s\"", logContent))
				deleteObjectFromS3Bucket(t, bucket, key, awsRegion)
			})

			test_structure.RunTestStage(t, "validate_kibana", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)

				var urlInfo UrlInfo
				test_structure.LoadTestData(t, fmt.Sprintf("%s/%s", examplesDir, URL_INFO_PATH), &urlInfo)

				var tlsCert keystore
				test_structure.LoadTestData(t, fmt.Sprintf("%s/%s", examplesDir, CERT_INFO_PATH), &tlsCert)

				kibanaBaseUrl := terraform.OutputRequired(t, terraformOptions, "alb_url")
				//kibanaBaseUrl := fmt.Sprintf("%s://%s.%s:%d", testCase.protocol, urlInfo.Subdomain, urlInfo.ZoneName, testCase.kibanaUIPort)
				kibanaStatusURL := fmt.Sprintf("%s/api/status", kibanaBaseUrl)

				acceptableBody := "\"state\":\"green\""
				testCase.checkerFunction(t, acceptableBody, kibanaStatusURL, &tlsCert, "")
			})

		})
	}
}

// SSH to the "App Server Box (the box with Filebeat running on it)
// and write a random message into the log being watched by Filebeat
// return that random message so that we can query out what kibana
// sees in elasticsearch and make sure that our random message is in there.
func writeAppServerLog(t *testing.T, sshHost ssh.Host, filebeatLogPath string) string {
	retry.DoWithRetry(
		t,
		fmt.Sprintf("SSH to public host %s", sshHost.Hostname),
		10,
		30*time.Second,
		func() (string, error) {
			return "", ssh.CheckSshConnectionE(t, sshHost)
		},
	)

	sampleEchoMessage := fmt.Sprintf("TEST_123_%s", random.UniqueId())

	// This sleep is undesirable, but there may be a difference between when
	// the above ssh command succeeds and when the instance has a chance to execute
	// the user-data script. We need to make sure user-data has executed before we try
	// to write our sample message as the location it is being written to gets created
	// by the user-data script.
	time.Sleep(30 * time.Second)

	_, err := ssh.CheckSshCommandE(t, sshHost, fmt.Sprintf("echo \"%s\" >> %s", sampleEchoMessage, filebeatLogPath))

	if err != nil {
		t.Logf("ERROR: Encountered when trying to call ssh command: %s", err.Error())
	}

	return sampleEchoMessage
}

func buildAllAmis(t *testing.T, awsRegion string, elasticsearchInfo *PackerInfo, logstashInfo *PackerInfo, appServerPackerInfo *PackerInfo, kibanaInfo *PackerInfo, elastalertInfo *PackerInfo, useSsl bool) *ElkAmis {
	var waitForAmis sync.WaitGroup
	waitForAmis.Add(5)

	var kibanaAmiId string
	var elasticsearchAmiId string
	var logstashAmiId string
	var appServerAmiId string
	var elastalertAmiId string

	go func() {
		defer waitForAmis.Done()
		elasticsearchAmiId = buildAmi(t, elasticsearchInfo.templatePath, elasticsearchInfo.builderName, awsRegion, useSsl)
	}()
	go func() {
		defer waitForAmis.Done()
		logstashAmiId = buildAmi(t, logstashInfo.templatePath, logstashInfo.builderName, awsRegion, useSsl)
	}()
	go func() {
		defer waitForAmis.Done()
		appServerAmiId = buildAmi(t, appServerPackerInfo.templatePath, appServerPackerInfo.builderName, awsRegion, useSsl)
	}()
	go func() {
		defer waitForAmis.Done()
		kibanaAmiId = buildAmi(t, kibanaInfo.templatePath, kibanaInfo.builderName, awsRegion, useSsl)
	}()
	go func() {
		defer waitForAmis.Done()
		elastalertAmiId = buildAmi(t, elastalertInfo.templatePath, elastalertInfo.builderName, awsRegion, useSsl)
	}()

	waitForAmis.Wait()

	if (elasticsearchAmiId == "") || (logstashAmiId == "") || (appServerAmiId == "") || (kibanaAmiId == "") || (elastalertAmiId == "") {
		t.Fatalf("One of the AMIs was blank: es:%s, logstash:%s, appserver:%s, kibana:%s, elastalert:%s", elasticsearchAmiId, logstashAmiId, appServerAmiId, kibanaAmiId, elastalertAmiId)
	}

	return &ElkAmis{
		ElasticsearchAmi: elasticsearchAmiId,
		LogstashAmi:      logstashAmiId,
		AppServerAmi:     appServerAmiId,
		KibanaAmi:        kibanaAmiId,
		ElastAlertAmi:    elastalertAmiId,
	}
}

func snapshotESAndLogstashLogs(
	t *testing.T,
	terraformOptions *terraform.Options,
	keyPair *aws.Ec2Keypair,
) {
	var localBaseDestDir string
	if os.Getenv("CIRCLECI") != "" {
		// On CircleCI, we want to store the logs in /tmp/logs so that they get artifacted
		localBaseDestDir = filepath.Join("/tmp/logs", "debug", t.Name())
	} else {
		localBaseDestDir = filepath.Join(".", "debug", t.Name())
	}

	if !files.FileExists(localBaseDestDir) {
		require.NoError(t, os.MkdirAll(localBaseDestDir, 0755))
	}

	logstashAsgNames := terraform.OutputList(t, terraformOptions, "logstash_server_asg_names")
	esAsgNames := terraform.OutputList(t, terraformOptions, "es_server_asg_names")
	appServerIP := terraform.Output(t, terraformOptions, "app_server_ip")
	appServerID := terraform.Output(t, terraformOptions, "app_server_id")

	// Get the app server logs
	localDestDir := filepath.Join(localBaseDestDir, appServerID)
	getLogsForHostByIP(t, appServerIP, keyPair, localDestDir)

	// Get the logs for ES and Logstash
	for _, asgName := range append(logstashAsgNames, esAsgNames...) {
		localDestDir := filepath.Join(localBaseDestDir, asgName)
		ip := getIPForInstanceInAsg(t, asgName, terraformOptions)
		getLogsForHostByIP(t, ip, keyPair, localDestDir)
	}
}

func getLogsForHostByIP(t *testing.T, ip string, keyPair *aws.Ec2Keypair, localDestDir string) {
	host := ssh.Host{
		Hostname:    ip,
		SshUserName: "ubuntu",
		SshKeyPair:  keyPair.KeyPair,
	}
	scpOptions := ssh.ScpDownloadOptions{
		RemoteHost:      host,
		RemoteDir:       "/var/log",
		LocalDir:        localDestDir,
		FileNameFilters: []string{"syslog", "user-data*", "es-cluster*", "logstash*"},
	}
	ssh.ScpDirFrom(t, scpOptions, true)
}

type PackerInfo struct {
	templatePath string
	builderName  string
}

type ElkAmis struct {
	ElasticsearchAmi string
	LogstashAmi      string
	AppServerAmi     string
	KibanaAmi        string
	ElastAlertAmi    string
}

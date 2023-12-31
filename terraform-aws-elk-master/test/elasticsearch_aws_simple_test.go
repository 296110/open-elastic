package test

import (
	"fmt"
	"os"
	"path/filepath"
	"strconv"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/files"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const GENERATE_KEYSTORE_SCRIPT_FOLDER = "generate-keystore"

func TestAWSElasticsearch(t *testing.T) {
	t.Parallel()

	//os.Setenv("SKIP_generate_ssl_certs", "true")
	//os.Setenv("SKIP_setup_ami", "true")
	//os.Setenv("SKIP_deploy_to_aws", "true")
	//os.Setenv("SKIP_validate", "true")
	//os.Setenv("SKIP_get_logs", "true")
	//os.Setenv("SKIP_teardown", "true")

	//zoneName := "gruntwork-sandbox.com" // Use this with Sandbox
	zoneName := "gruntwork.in" // Use this with PhxDevops

	var testcases = []struct {
		testName                   string
		packerTemplateFileName     string
		packerBuilder              string
		terraformDir               string
		elasticsearchPort          int
		elasticsearchDiscoveryPort int
		useSsl                     bool
		keystoreFile               string
		keystorePass               string
		certKeyPass                string
		certAlias                  string
		protocol                   string
		checkerFunction            func(t *testing.T, messageToVerify string, webConsoleUrl string, keyStore *keystore, kibanaPass string)
	}{
		{
			"TestElasticsearchUbuntu1804",
			"elasticsearch.json",
			"elasticsearch-ami-ubuntu-18",
			"elasticsearch-only-cluster",
			9200,
			9300,
			false,
			"",
			"",
			"",
			"",
			"http",
			validateGetHttp,
		},
		{
			"TestElasticsearchSSLUbuntu2004",
			"elasticsearch.json",
			"elasticsearch-ami-ubuntu-20",
			"elasticsearch-only-cluster",
			9200,
			9300,
			true,
			"elasticsearch.server.keystore.jks",
			"password",
			"password",
			"localhost",
			"https",
			validateGetHttps,
		},
		{
			"TestElasticsearchUbuntu2004",
			"elasticsearch.json",
			"elasticsearch-ami-ubuntu-20",
			"elasticsearch-only-cluster",
			9200,
			9300,
			false,
			"",
			"",
			"",
			"",
			"http",
			validateGetHttp,
		},
	}

	for _, testCase := range testcases {
		// The following is necessary to make sure testCase's values don't
		// get updated due to concurrency within the scope of t.Run(..) below
		testCase := testCase

		t.Run(testCase.testName, func(t *testing.T) {
			t.Parallel()

			examplesDir := test_structure.CopyTerraformFolderToTemp(t, "../", "examples")

			defer test_structure.RunTestStage(t, "teardown", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				terraform.Destroy(t, terraformOptions)
			})

			defer test_structure.RunTestStage(t, "get_logs", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)
				if t.Failed() {
					snapshotLogs(t, terraformOptions, keyPair)
				}
			})

			test_structure.RunTestStage(t, "generate_ssl_certs", func() {
				tlsOutputDir := fmt.Sprintf("%s/elk-amis", examplesDir)
				generateKeystoreDir := fmt.Sprintf("%s/%s", examplesDir, GENERATE_KEYSTORE_SCRIPT_FOLDER)
				downloadGenerateKeystoreScript(t, generateKeystoreDir)
				tlsCert := createKeyStoreFiles(t, "elasticsearch", generateKeystoreDir, tlsOutputDir, zoneName)
				test_structure.SaveTestData(t, fmt.Sprintf("%s/.test-data/CERT.json", examplesDir), tlsCert)
			})

			test_structure.RunTestStage(t, "setup_ami", func() {

				awsRegion := aws.GetRandomStableRegion(t, RegionsWithGruntworkINACM, nil)
				templatePath := fmt.Sprintf("%s/elk-amis/elasticsearch/%s", examplesDir, testCase.packerTemplateFileName)
				amiId := buildAmi(t, templatePath, testCase.packerBuilder, awsRegion, testCase.useSsl)

				clusterName := fmt.Sprintf("es-cluster-%s", random.UniqueId())

				keyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, random.UniqueId())
				test_structure.SaveEc2KeyPair(t, examplesDir, keyPair)

				terraformOptions := generateTerraformOptions(
					t,
					fmt.Sprintf("%s/%s", examplesDir, testCase.terraformDir),
					awsRegion, amiId, clusterName, zoneName, keyPair.Name)

				if testCase.useSsl {
					terraformOptions.Vars["use_ssl"] = strconv.FormatBool(testCase.useSsl)
					terraformOptions.Vars["java_keystore_filename"] = testCase.keystoreFile
					terraformOptions.Vars["java_keystore_password"] = testCase.keystorePass
					terraformOptions.Vars["java_keystore_certificate_password"] = testCase.certKeyPass
					terraformOptions.Vars["java_keystore_cert_alias"] = testCase.certAlias
				}

				test_structure.SaveTerraformOptions(t, examplesDir, terraformOptions)
			})

			test_structure.RunTestStage(t, "deploy_to_aws", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				terraform.InitAndApply(t, terraformOptions)
			})

			test_structure.RunTestStage(t, "validate", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				var tlsCert keystore
				test_structure.LoadTestData(t, fmt.Sprintf("%s/.test-data/CERT.json", examplesDir), &tlsCert)

				// Run `terraform output` to get the value of an output variable
				loadbalancerDNS := terraform.Output(t, terraformOptions, "lb_dns_name")
				elasticsearchURL := fmt.Sprintf("%s://%s:%d", testCase.protocol, loadbalancerDNS, testCase.elasticsearchPort)

				acceptableBody := fmt.Sprintf("\"cluster_name\" : \"%s\"", terraformOptions.Vars["cluster_name"])

				testCase.checkerFunction(t, acceptableBody, elasticsearchURL, &tlsCert, "password")
			})
		})
	}
}

func snapshotLogs(
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

	asgNames := terraform.OutputList(t, terraformOptions, "server_asg_names")

	for _, asgName := range asgNames {
		localDestDir := filepath.Join(localBaseDestDir, asgName)
		if !files.FileExists(localBaseDestDir) {
			os.MkdirAll(localBaseDestDir, 0755)
		}

		ip := getIPForInstanceInAsg(t, asgName, terraformOptions)

		host := ssh.Host{
			Hostname:    ip,
			SshUserName: "ubuntu",
			SshKeyPair:  keyPair.KeyPair,
		}
		scpOptions := ssh.ScpDownloadOptions{
			RemoteHost:      host,
			RemoteDir:       "/var/log",
			LocalDir:        localDestDir,
			FileNameFilters: []string{"syslog", "es-cluster*"},
		}
		ssh.ScpDirFrom(t, scpOptions, true)
	}
}

func generateTerraformOptions(t *testing.T, terraformDir string, awsRegion string, amiId string, clusterName string, zoneName string, keyPairName string) *terraform.Options {
	largeInstanceType := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.large", "t3.large"})
	return &terraform.Options{
		// The path to where your Terraform code is located
		TerraformDir: terraformDir,
		Vars: map[string]interface{}{
			"aws_region":        awsRegion,
			"ami_id":            amiId,
			"instance_type":     largeInstanceType,
			"cluster_name":      clusterName,
			"key_name":          keyPairName,
			"route53_zone_name": zoneName,
		},
	}
}

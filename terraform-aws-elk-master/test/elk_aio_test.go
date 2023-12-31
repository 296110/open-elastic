package test

import (
	"fmt"
	"strings"
	"testing"

	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

const LogstashFileOutputPath = "/var/log/destination.log"

func TestELKAIOEndToEnd(t *testing.T) {
	t.Parallel()

	// For convenience - uncomment these as well as the "os" import
	// when doing local testing if you need to skip any sections.
	// os.Setenv("SKIP_", "true")
	// os.Setenv("TERRATEST_REGION", "us-east-1")
	// os.Setenv("SKIP_setup_ami", "true")
	// os.Setenv("SKIP_deploy_to_aws", "true")
	// os.Setenv("SKIP_validate", "true")
	// os.Setenv("SKIP_validate_collectd", "true")
	// os.Setenv("SKIP_validate_cloudtrail", "true")
	// os.Setenv("SKIP_validate_cloudwatch", "true")
	// os.Setenv("SKIP_validate_kibana", "true")
	// os.Setenv("SKIP_teardown", "true")

	var testcases = []struct {
		testName                   string
		elasticsearchPort          int
		elasticsearchDiscoveryPort int
		kibanaUIPort               int
		elkPackerInfo              PackerInfo
	}{
		{
			"TestElasticsearchUbuntu2004",
			9200,
			9300,
			5601,
			PackerInfo{
				builderName: "elk-aio-ami-ubuntu-20",
			},
		},
		{
			"TestElasticsearchUbuntu1804",
			9200,
			9300,
			5601,
			PackerInfo{
				builderName: "elk-aio-ami-ubuntu-18",
			},
		},
	}

	for _, testCase := range testcases {
		// The following is necessary to make sure testCase's values don't
		// get updated due to concurrency within the scope of t.Run(..) below
		testCase := testCase

		t.Run(testCase.testName, func(t *testing.T) {
			t.Parallel()

			examplesDir := test_structure.CopyTerraformFolderToTemp(t, "../", "examples")
			elkAmisDir := fmt.Sprintf("%s/elk-amis", examplesDir)
			testCase.elkPackerInfo.templatePath = fmt.Sprintf("%s/all-in-one/all-in-one.json", elkAmisDir)

			defer test_structure.RunTestStage(t, "teardown", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				terraform.Destroy(t, terraformOptions)
			})

			test_structure.RunTestStage(t, "setup_ami", func() {
				awsRegion := aws.GetRandomStableRegion(t, nil, []string{"ap-southeast-1", "sa-east-1"})
				test_structure.SaveString(t, examplesDir, "awsRegion", awsRegion)

				amiId := buildAmi(t, testCase.elkPackerInfo.templatePath, testCase.elkPackerInfo.builderName, awsRegion, false)

				uniqueId := strings.ToLower(random.UniqueId())
				elkClusterName := fmt.Sprintf("es-%s", uniqueId)
				albName := fmt.Sprintf("alb-%s", uniqueId)

				keyPair := aws.CreateAndImportEC2KeyPair(t, awsRegion, uniqueId)
				test_structure.SaveEc2KeyPair(t, examplesDir, keyPair)

				terraformOptions := &terraform.Options{
					// The path to where your Terraform code is located
					TerraformDir: fmt.Sprintf("%s/elk-single-cluster", examplesDir),
					Vars: map[string]interface{}{
						"aws_region":        awsRegion,
						"ami_id":            amiId,
						"elk_cluster_name":  elkClusterName,
						"filebeat_log_path": "/var/log/source.log",
						"key_name":          keyPair.Name,
						"alb_name":          albName,
					},
				}

				test_structure.SaveTerraformOptions(t, examplesDir, terraformOptions)
			})

			test_structure.RunTestStage(t, "deploy_to_aws", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				terraform.InitAndApply(t, terraformOptions)
			})

			test_structure.RunTestStage(t, "validate", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				asgName := terraform.OutputList(t, terraformOptions, "server_asg_names")[0]

				ip := getIPForInstanceInAsg(t, asgName, terraformOptions)
				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)

				host := ssh.Host{
					Hostname:    ip,
					SshUserName: "ubuntu",
					SshKeyPair:  keyPair.KeyPair,
				}

				randomMessage := writeAppServerLog(t, host, terraformOptions.Vars["filebeat_log_path"].(string))

				loadbalancerDns := terraform.Output(t, terraformOptions, "alb_dns_name")
				elasticsearchUrl := fmt.Sprintf("http://%s:%d", loadbalancerDns, testCase.elasticsearchPort)
				queryUrl := fmt.Sprintf("%s/_all/_search?q=message:%s", elasticsearchUrl, randomMessage)

				validateGetHttp(t, randomMessage, queryUrl, nil, "")
			})

			test_structure.RunTestStage(t, "validate_collectd", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)

				asgName := terraform.OutputList(t, terraformOptions, "server_asg_names")[0]
				publicInstanceIP := getIPForInstanceInAsg(t, asgName, terraformOptions)

				checkLogstashOutputLog(t, publicInstanceIP, "ubuntu", *keyPair, LogstashFileOutputPath, fmt.Sprintf("\"x_forwarded_for\":\"%s\"", publicInstanceIP))
			})

			test_structure.RunTestStage(t, "validate_cloudwatch", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)
				awsRegion := test_structure.LoadString(t, examplesDir, "awsRegion")

				logGroup := terraform.Output(t, terraformOptions, "log_group")
				logContent := "This is a log line_cloudwatch"

				writeContentToLogStream(t, logGroup, logContent, awsRegion)

				asgName := terraform.OutputList(t, terraformOptions, "server_asg_names")[0]
				publicInstanceIP := getIPForInstanceInAsg(t, asgName, terraformOptions)

				checkLogstashOutputLog(t, publicInstanceIP, "ubuntu", *keyPair, LogstashFileOutputPath, fmt.Sprintf("\"message\":\"%s\"", logContent))
			})

			test_structure.RunTestStage(t, "validate_cloudtrail", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				keyPair := test_structure.LoadEc2KeyPair(t, examplesDir)
				awsRegion := test_structure.LoadString(t, examplesDir, "awsRegion")

				logContent := "This is a log line_cloudtrail"

				bucket := terraform.Output(t, terraformOptions, "bucket")
				key := writeContentToS3Bucket(t, bucket, logContent, awsRegion)

				asgName := terraform.OutputList(t, terraformOptions, "server_asg_names")[0]
				publicInstanceIP := getIPForInstanceInAsg(t, asgName, terraformOptions)

				checkLogstashOutputLog(t, publicInstanceIP, "ubuntu", *keyPair, LogstashFileOutputPath, fmt.Sprintf("\"message\":\"%s\"", logContent))
				deleteObjectFromS3Bucket(t, bucket, key, awsRegion)
			})

			test_structure.RunTestStage(t, "validate_kibana", func() {
				terraformOptions := test_structure.LoadTerraformOptions(t, examplesDir)
				// Run `terraform output` to get the value of an output variable
				loadbalancerDNS := terraform.Output(t, terraformOptions, "alb_dns_name")
				kibanaStatusURL := fmt.Sprintf("http://%s/api/status", loadbalancerDNS)

				checkAWSKibanaRunning(t, kibanaStatusURL)
			})
		})
	}
}

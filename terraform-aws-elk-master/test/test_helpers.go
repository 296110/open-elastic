package test

import (
	"crypto/tls"
	"fmt"
	"net"
	"os"
	"strconv"
	"strings"
	"testing"
	"time"

	awsgo "github.com/aws/aws-sdk-go/aws"
	"github.com/aws/aws-sdk-go/aws/session"
	"github.com/aws/aws-sdk-go/service/autoscaling"
	"github.com/aws/aws-sdk-go/service/cloudwatchlogs"
	"github.com/aws/aws-sdk-go/service/ec2"
	"github.com/aws/aws-sdk-go/service/s3"
	"github.com/gruntwork-io/terratest/modules/aws"
	"github.com/gruntwork-io/terratest/modules/docker"
	"github.com/gruntwork-io/terratest/modules/git"
	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/logger"
	"github.com/gruntwork-io/terratest/modules/packer"
	"github.com/gruntwork-io/terratest/modules/random"
	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/ssh"
	"github.com/gruntwork-io/terratest/modules/terraform"
)

type UrlInfo struct {
	Subdomain string
	ZoneName  string
}

var RegionsWithGruntworkINACM = []string{
	"us-east-1",
	"us-east-2",
	"us-west-1",
	"us-west-2",
	"eu-west-1",
	"eu-west-2",
}

func startStackInDockerCompose(t *testing.T, exampleDir string, envVars map[string]string) {
	options := &docker.Options{
		EnvVars:    envVars,
		WorkingDir: exampleDir,
	}

	docker.RunDockerCompose(t, options, "up", "-d")
}

func stopStackInDockerCompose(t *testing.T, exampleDir string, envVars map[string]string) {
	options := &docker.Options{
		EnvVars:    envVars,
		WorkingDir: exampleDir,
	}

	docker.RunDockerCompose(t, options, "down")
}

func getLogs(t *testing.T, workingDir string, envVars map[string]string) {
	options := &docker.Options{
		EnvVars:    envVars,
		WorkingDir: workingDir,
	}

	if t.Failed() {
		t.Log(docker.RunDockerCompose(t, options, "logs"))
	}
}

func buildDockerImage(t *testing.T, templatePath string, builderName string) {
	curBranch := git.GetCurrentBranchName(t)
	options := &packer.Options{
		Template: templatePath,
		Only:     builderName,
		Vars: map[string]string{
			"module_branch":               curBranch,
			"module_elasticsearch_branch": curBranch,
			"module_filebeat_branch":      curBranch,
			"module_kibana_branch":        curBranch,
			"module_logstash_branch":      curBranch,
			"module_collectd_branch":      curBranch,
		},
	}

	packer.BuildAmi(t, options)
}

func buildAmi(t *testing.T, templatePath string, builderName string, awsRegion string, useSsl bool) string {
	curBranch := git.GetCurrentBranchName(t)
	smallInstanceType := aws.GetRecommendedInstanceType(t, awsRegion, []string{"t2.small", "t3.small"})
	options := &packer.Options{
		Template: templatePath,
		Only:     builderName,
		Vars: map[string]string{
			"aws_region":                  awsRegion,
			"instance_type":               smallInstanceType,
			"use_ssl":                     strconv.FormatBool(useSsl),
			"module_branch":               curBranch,
			"module_elasticsearch_branch": curBranch,
			"module_filebeat_branch":      curBranch,
			"module_kibana_branch":        curBranch,
			"module_logstash_branch":      curBranch,
			"module_collectd_branch":      curBranch,
			"module_app_server_branch":    curBranch,
		},
	}

	return packer.BuildAmi(t, options)
}

func tcpRequestWithRetry(t *testing.T, addr string, maxRetries int, sleepBetweenRetries time.Duration) {
	tcpAddr, err := net.ResolveTCPAddr("tcp", addr)
	if err != nil {
		t.Fatalf("Unable to resolve TCP address: '%s' cannot be parsed", addr)
	}

	for i := 0; i < maxRetries; i++ {
		t.Logf("Making a TCP request to %s", addr)
		_, err = net.DialTCP("tcp", nil, tcpAddr)
		if err == nil {
			t.Log("TCP request was successful")
			return
		}

		t.Logf("Couldn't reach TCP address %s. Sleeping for %ds", addr, sleepBetweenRetries)
		time.Sleep(sleepBetweenRetries)
	}

	t.Fatalf("Unable to reach TCP address %s:", addr)
}

func checkLogstashRunning(t *testing.T, dns string, port string) {
	maxRetries := 180
	sleepBetweenRetries := 5 * time.Second
	url := fmt.Sprintf("%s:%s", dns, port)

	logger.Logf(t, "Checking for Logstash to be up at: %s", url)
	tcpRequestWithRetry(t, url, maxRetries, sleepBetweenRetries)
}

func skipInCircleCi(t *testing.T) {
	if os.Getenv("CIRCLECI") != "" {
		t.Skip("Skipping Docker unit tests in CircleCI, as for some crazy reason, Couchbase often fails to start in a Docker container when running in CircleCI. See https://github.com/gruntwork-io/terraform-aws-couchbase/pull/10 for details.")
	}
}

func getIPForInstanceInAsg(t *testing.T, asgName string, terraformOptions *terraform.Options) string {
	asg := findAsg(t, asgName, terraformOptions)

	if len(asg.Instances) == 0 {
		t.Fatalf("Auto Scaling Group %s has no instances", asgName)
	}

	return getIPForInstance(t, *asg.Instances[0].InstanceId, terraformOptions)
}

func findAsg(t *testing.T, asgName string, terraformOptions *terraform.Options) *autoscaling.Group {
	svc := autoscaling.New(session.New(), awsgo.NewConfig().WithRegion(terraformOptions.Vars["aws_region"].(string)))

	input := &autoscaling.DescribeAutoScalingGroupsInput{AutoScalingGroupNames: []*string{awsgo.String(asgName)}}
	output, err := svc.DescribeAutoScalingGroups(input)
	if err != nil {
		t.Fatal(err.Error())
	}

	for _, group := range output.AutoScalingGroups {
		if *group.AutoScalingGroupName == asgName {
			return group
		}
	}

	t.Fatalf("Could not find an Auto Scaling Group named %s", asgName)
	return nil
}

func getIPForInstance(t *testing.T, instanceID string, terraformOptions *terraform.Options) string {
	svc := ec2.New(session.New(), awsgo.NewConfig().WithRegion(terraformOptions.Vars["aws_region"].(string)))

	input := &ec2.DescribeInstancesInput{InstanceIds: []*string{awsgo.String(instanceID)}}
	output, err := svc.DescribeInstances(input)
	if err != nil {
		t.Fatal(err.Error())
	}

	for _, reservation := range output.Reservations {
		for _, instance := range reservation.Instances {
			if awsgo.StringValue(instance.InstanceId) == instanceID && instance.PublicIpAddress != nil {
				return awsgo.StringValue(instance.PublicIpAddress)
			}
		}
	}

	t.Fatalf("Could not find an instance with id %s", instanceID)
	return ""
}

func checkLogstashOutputLog(t *testing.T, publicInstanceIP string, username string, keyPair aws.Ec2Keypair, logPath string, logContent string) {
	publicHost := ssh.Host{
		Hostname:    publicInstanceIP,
		SshKeyPair:  keyPair.KeyPair,
		SshUserName: username,
	}

	// It can take a minute or so for the Instance to boot up, so retry a few times
	maxRetries := 20
	timeBetweenRetries := 10 * time.Second
	description := fmt.Sprintf("SSH to public host %s", publicInstanceIP)

	command := fmt.Sprintf("sudo cat %s", logPath)

	// Verify that we can SSH to the Instance and run commands
	retry.DoWithRetry(t, description, maxRetries, timeBetweenRetries, func() (string, error) {
		contents, err := ssh.CheckSshCommandE(t, publicHost, command)

		if err != nil {
			t.Log(err.Error())
			return "", err
		}

		if contents == "" {
			return "", fmt.Errorf("Logstash did not write to a destination log file")
		}

		if !strings.Contains(contents, logContent) {
			return "", fmt.Errorf(fmt.Sprintf("Logstash did not write the correct content '%s' to the destination log file", logContent))
		}

		return "", nil
	})
}

func writeContentToS3Bucket(t *testing.T, bucket string, content string, awsRegion string) string {
	key := random.UniqueId()
	_, err := s3.New(session.New(), awsgo.NewConfig().WithRegion(awsRegion)).PutObject(&s3.PutObjectInput{
		Bucket:               awsgo.String(bucket),
		Key:                  awsgo.String(key),
		ACL:                  awsgo.String("public-read"),
		Body:                 strings.NewReader(content),
		ContentType:          awsgo.String("text/plain"),
		ContentDisposition:   awsgo.String("attachment"),
		ServerSideEncryption: awsgo.String("AES256"),
	})

	if err != nil {
		t.Fatal(err.Error())
	}

	return key
}

func deleteObjectFromS3Bucket(t *testing.T, bucket string, key string, awsRegion string) {
	_, err := s3.New(session.New(), awsgo.NewConfig().WithRegion(awsRegion)).DeleteObject(&s3.DeleteObjectInput{
		Bucket: awsgo.String(bucket),
		Key:    awsgo.String(key),
	})

	if err != nil {
		t.Fatal(err.Error())
	}
}

func writeContentToLogStream(t *testing.T, logGroup string, content string, awsRegion string) {
	svc := cloudwatchlogs.New(session.New(), awsgo.NewConfig().WithRegion(awsRegion))

	streams, err := svc.DescribeLogStreams(&cloudwatchlogs.DescribeLogStreamsInput{
		LogGroupName: awsgo.String(logGroup),
	})

	if err != nil {
		t.Fatal(err.Error())
	}

	logStream := streams.LogStreams[0]

	_, err = svc.PutLogEvents(&cloudwatchlogs.PutLogEventsInput{
		SequenceToken: logStream.UploadSequenceToken,
		LogGroupName:  awsgo.String(logGroup),
		LogStreamName: logStream.LogStreamName,
		LogEvents: []*cloudwatchlogs.InputLogEvent{
			&cloudwatchlogs.InputLogEvent{
				Message:   awsgo.String(content),
				Timestamp: awsgo.Int64(time.Now().UnixNano() / int64(time.Millisecond)),
			},
		},
	})

	if err != nil {
		t.Fatal(err.Error())
	}
}

func checkAWSKibanaRunning(t *testing.T, kibanaStatusURL string) {
	maxRetries := 30
	sleepBetweenRetries := 5 * time.Second

	logger.Log(t, "Checking for Kibana to be up at: %s", kibanaStatusURL)

	acceptableBody := "\"state\":\"green\""

	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		kibanaStatusURL,
		&tls.Config{},
		maxRetries,
		sleepBetweenRetries,
		func(status int, body string) bool {
			return status == 200 && strings.Contains(body, acceptableBody)
		},
	)
}

func validateGetHttp(t *testing.T, messageToVerify string, queryUrl string, cert *keystore, kibanaPass string) {
	// Try up to 5 minutes
	maxRetries := 75
	sleepBetweenRetries := 4 * time.Second

	logger.Log(t, "Checking URL: %s to have the text: %s", queryUrl, messageToVerify)

	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		queryUrl,
		&tls.Config{},
		maxRetries,
		sleepBetweenRetries,
		func(status int, body string) bool {
			return status == 200 && strings.Contains(body, messageToVerify)
		},
	)
}

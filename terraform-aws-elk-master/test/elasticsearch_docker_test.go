package test

import (
	"crypto/tls"
	"fmt"
	"strconv"
	"strings"
	"testing"
	"time"

	http_helper "github.com/gruntwork-io/terratest/modules/http-helper"
	"github.com/gruntwork-io/terratest/modules/logger"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

func TestTLSLocalDocker(t *testing.T) {
	// Skip Docker Tests in CircleCI because these tests are resource intensive and
	// we just can't seem to get the tests to run reliably on CircleCI's hardware
	skipInCircleCi(t)

	GENERATE_KEYSTORE_SCRIPT_DIR := "/tmp/generate-keystore"

	examplesDir := "../examples"
	workingDir := fmt.Sprintf("%s/elasticsearch-docker/ssl", examplesDir)

	tlsOutputDir := fmt.Sprintf("%s/elasticsearch-ami", examplesDir)
	downloadGenerateKeystoreScript(t, GENERATE_KEYSTORE_SCRIPT_DIR)
	tlsCert := createKeyStoreFiles(t, "elasticsearch", GENERATE_KEYSTORE_SCRIPT_DIR, tlsOutputDir, "gruntwork.io")

	var testcases = []struct {
		testName                   string
		packerBuilder              string
		osName                     string
		elasticsearchPort          int
		elasticsearchDiscoveryPort int
	}{
		{"TestElasticsearchUbuntu1604Docker", "elasticsearch-ssl-docker-ubuntu", "ubuntu", 9208, 9308},
		{"TestElasticsearchUbuntu1804Docker", "elasticsearch-ssl-docker-ubuntu-18", "ubuntu", 9208, 9308},
		{"TestElasticsearchAmazonDocker", "elasticsearch-ssl-docker-amazon-linux", "amazon-linux", 9209, 9309},
	}

	for _, testCase := range testcases {
		// The following is necessary to make sure testCase's values don't
		// get updated due to concurrency within the scope of t.Run(..) below
		testCase := testCase

		t.Run(testCase.testName, func(t *testing.T) {
			t.Parallel()

			packerTemplatePath := fmt.Sprintf("%s/elk-amis/elasticsearch/elasticsearch-ssl.json", examplesDir)
			buildDockerImage(t, packerTemplatePath, testCase.packerBuilder)

			envVars := map[string]string{
				"OS_NAME":                      testCase.osName,
				"PROTOCOL":                     "https",
				"ELASTICSEARCH_PORT":           strconv.Itoa(testCase.elasticsearchPort),
				"ELASTICSEARCH_DISCOVERY_PORT": strconv.Itoa(testCase.elasticsearchDiscoveryPort),
				"CONTAINER_BASE_NAME":          "elasticsearch-ssl",
			}

			runTestScript(t, testCase.testName, workingDir, envVars, tlsCert, validateGetHttps)
		})
	}
}

func TestLocalDockerElasticsearch(t *testing.T) {
	t.Parallel()

	// Skip Docker Tests in CircleCI because these tests are resource intensive and
	// we just can't seem to get the tests to run reliably on CircleCI's hardware
	skipInCircleCi(t)

	examplesDir := "../examples"
	workingDir := fmt.Sprintf("%s/elasticsearch-docker/non-ssl", examplesDir)

	var testcases = []struct {
		testName                   string
		packerBuilder              string
		osName                     string
		elasticsearchPort          int
		elasticsearchDiscoveryPort int
	}{
		{"TestElasticsearchUbuntu1604Docker", "elasticsearch-docker-ubuntu", "ubuntu", 9202, 9302},
		{"TestElasticsearchUbuntu1804Docker", "elasticsearch-docker-ubuntu-18", "ubuntu", 9202, 9302},
		{"TestElasticsearchAmazonDocker", "elasticsearch-docker-amazon-linux", "amazon-linux", 9201, 9301},
	}

	for _, testCase := range testcases {
		// The following is necessary to make sure testCase's values don't
		// get updated due to concurrency within the scope of t.Run(..) below
		testCase := testCase

		t.Run(testCase.testName, func(t *testing.T) {
			t.Parallel()

			templatePath := fmt.Sprintf("%s/elk-amis/elasticsearch/elasticsearch.json", examplesDir)
			buildDockerImage(t, templatePath, testCase.packerBuilder)

			envVars := map[string]string{
				"OS_NAME":                      testCase.osName,
				"PROTOCOL":                     "http",
				"ELASTICSEARCH_PORT":           strconv.Itoa(testCase.elasticsearchPort),
				"ELASTICSEARCH_DISCOVERY_PORT": strconv.Itoa(testCase.elasticsearchDiscoveryPort),
				"CONTAINER_BASE_NAME":          "elasticsearch",
			}
			runTestScript(t, testCase.testName, workingDir, envVars, nil, checkElasticsearchRunning)
		})
	}
}

func runTestScript(t *testing.T, testName string, workingDir string, envVars map[string]string, keyStore *keystore, checkerFunction func(t *testing.T, clusterName string, webConsoleUrl string, keyStore *keystore, password string)) {
	test_structure.RunTestStage(t, fmt.Sprintf("Running test: %s", testName), func() {

		startStackInDockerCompose(t, workingDir, envVars)
		defer stopStackInDockerCompose(t, workingDir, envVars)
		defer getLogs(t, workingDir, envVars)

		elasticsearchURL := fmt.Sprintf("%s://localhost:%s", envVars["PROTOCOL"], envVars["ELASTICSEARCH_PORT"])

		checkerFunction(t, "mock-elasticsearch-server", elasticsearchURL, keyStore, "")
	})
}

func checkElasticsearchRunning(t *testing.T, clusterName string, webConsoleUrl string, keyStore *keystore, password string) {
	maxRetries := 180
	sleepBetweenRetries := 5 * time.Second

	logger.Logf(t, "Checking for Elasticsearch to be up at: %s", webConsoleUrl)

	http_helper.HttpGetWithRetryWithCustomValidation(
		t,
		webConsoleUrl,
		&tls.Config{},
		maxRetries,
		sleepBetweenRetries,
		func(status int, body string) bool {
			return status == 200 && strings.Contains(body, fmt.Sprintf("\"cluster_name\" : \"%s\"", clusterName))
		},
	)
}

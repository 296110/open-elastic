package test

import (
	"crypto/x509"
	"encoding/base64"
	"errors"
	"fmt"
	"io/ioutil"
	"log"
	"net/http"
	"os/user"
	"strings"
	"testing"
	"time"

	"github.com/gruntwork-io/terratest/modules/retry"
	"github.com/gruntwork-io/terratest/modules/terraform"
	test_structure "github.com/gruntwork-io/terratest/modules/test-structure"
)

type TlsCert struct {
	CAPublicKeyPath string
	PublicKeyPath   string
	PrivateKeyPath  string
}

const PRIVATE_TLS_CERT_PATH = "modules/private-tls-cert"

const REPO_ROOT = "../"

const VAR_CA_PUBLIC_KEY_FILE_PATH = "ca_public_key_file_path"
const VAR_PUBLIC_KEY_FILE_PATH = "public_key_file_path"
const VAR_PRIVATE_KEY_FILE_PATH = "private_key_file_path"
const VAR_OWNER = "owner"
const VAR_ORGANIZATION_NAME = "organization_name"
const VAR_CA_COMMON_NAME = "ca_common_name"
const VAR_COMMON_NAME = "common_name"
const VAR_DNS_NAMES = "dns_names"
const VAR_IP_ADDRESSES = "ip_addresses"
const VAR_VALIDITY_PERIOD_HOURS = "validity_period_hours"

// Use the private-tls-cert module to generate a self-signed TLS certificate
func generateSelfSignedTlsCert(t *testing.T) TlsCert {
	currentUser, err := user.Current()
	if err != nil {
		t.Fatalf("Couldn't get current OS user: %v", err)
	}

	caPublicKeyFilePath, err := ioutil.TempFile("", "ca-public-key")
	if err != nil {
		t.Fatalf("Couldn't create temp file: %v", err)
	}

	publicKeyFilePath, err := ioutil.TempFile("", "tls-public-key")
	if err != nil {
		t.Fatalf("Couldn't create temp file: %v", err)
	}

	privateKeyFilePath, err := ioutil.TempFile("", "tls-private-key")
	if err != nil {
		t.Fatalf("Couldn't create temp file: %v", err)
	}

	examplesDir := test_structure.CopyTerraformFolderToTemp(t, REPO_ROOT, PRIVATE_TLS_CERT_PATH)

	terraformOptions := &terraform.Options{
		TerraformDir: examplesDir,
		Vars: map[string]interface{}{
			VAR_CA_PUBLIC_KEY_FILE_PATH: caPublicKeyFilePath.Name(),
			VAR_PUBLIC_KEY_FILE_PATH:    publicKeyFilePath.Name(),
			VAR_PRIVATE_KEY_FILE_PATH:   privateKeyFilePath.Name(),
			VAR_OWNER:                   currentUser.Username,
			VAR_ORGANIZATION_NAME:       "Gruntwork",
			VAR_CA_COMMON_NAME:          "Vault Module Test CA",
			VAR_COMMON_NAME:             "Vault Module Test",
			VAR_DNS_NAMES:               []string{"vault.service.consul"},
			VAR_IP_ADDRESSES:            []string{"127.0.0.1"},
			VAR_VALIDITY_PERIOD_HOURS:   1000,
		},
	}

	defer terraform.Destroy(t, terraformOptions)

	terraform.InitAndApply(t, terraformOptions)

	return TlsCert{
		CAPublicKeyPath: caPublicKeyFilePath.Name(),
		PublicKeyPath:   publicKeyFilePath.Name(),
		PrivateKeyPath:  privateKeyFilePath.Name(),
	}
}

func validateGetHttps(t *testing.T, messageToVerify string, queryUrl string, keyStore *keystore, kibanaPass string) {
	maxRetries := 180
	sleepBetweenRetries := 5 * time.Second
	_, err := retry.DoWithRetryE(t, "HTTPS GET", maxRetries, sleepBetweenRetries, func() (string, error) {
		caCert, err := ioutil.ReadFile(keyStore.CaFile)
		if err != nil {
			log.Fatal(err)
		}
		caCertPool := x509.NewCertPool()
		caCertPool.AppendCertsFromPEM(caCert)

		client := &http.Client{
			Transport: &http.Transport{
				TLSClientConfig: keyStore.getTlsConfig(t),
			},
		}

		req, err := http.NewRequest("GET", queryUrl, nil)
		if err != nil {
			return "", err
		}

		// Add basic auth info, which is required to access ES when we introduce readonlyrest
		basicAuthStr := fmt.Sprintf("kibana:%s", kibanaPass)
		req.Header.Set(
			"Authorization",
			fmt.Sprintf("Basic %s", base64.StdEncoding.EncodeToString([]byte(basicAuthStr))),
		)

		resp, err := client.Do(req)
		if err != nil {
			return "", err
		}

		htmlData, err := ioutil.ReadAll(resp.Body)
		if err != nil {
			fmt.Println(err)
			return "", err
		}

		htmlBody := string(htmlData)

		if !strings.Contains(htmlBody, messageToVerify) {
			return "", errors.New(fmt.Sprintf("Resulting data: [ \n%s\n ] from URL %s did not contain verificationText: %s", htmlBody, queryUrl, messageToVerify))
		}

		return htmlBody, nil

	})

	if err != nil {
		t.Fatalf("Error: %s", err.Error())
	}
}

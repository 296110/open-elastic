package test

import (
	"crypto/tls"
	"crypto/x509"
	"fmt"
	"io/ioutil"
	"path/filepath"
	"testing"

	"github.com/gruntwork-io/terratest/modules/shell"
)

// Represents a Java KeyStore
type keystore struct {
	CertFile           string
	KeyFile            string
	P8KeyFile          string
	CaFile             string
	KeyStorePath       string
	KeyStorePassword   string
	TrustStorePath     string
	TrustStorePassword string
}

func createKeyStoreFiles(t *testing.T, name string, repoPath string, amiDir string, domain string) *keystore {
	sslBasePath := filepath.Join(amiDir, "ssl")
	keyStoreFile := filepath.Join(sslBasePath, fmt.Sprintf("%s.server.keystore.jks", name))
	trustStoreFile := filepath.Join(sslBasePath, fmt.Sprintf("%s.server.truststore.jks", name))
	certFile := filepath.Join(sslBasePath, "localhost.pem")
	keyFile := filepath.Join(sslBasePath, "localhost.key")
	caFile := filepath.Join(sslBasePath, "caFile")
	password := "password"

	generateKeyStores(t, repoPath, password, keyStoreFile, trustStoreFile, certFile, keyFile, caFile, domain)

	keystore := &keystore{
		CertFile:           certFile,
		KeyFile:            keyFile,
		CaFile:             caFile,
		KeyStorePath:       keyStoreFile,
		KeyStorePassword:   password,
		TrustStorePath:     trustStoreFile,
		TrustStorePassword: password,
	}

	return keystore
}

func generateKeyStores(t *testing.T, repoCopyPath string, password string, keyStoreFile string, trustStoreFile string, certFile string, keyFile string, caFile string, domain string) {
	cmdDeletePrevious := shell.Command{
		Command: "rm",
		Args: []string{
			"-rf",
			keyStoreFile,
			trustStoreFile,
			certFile,
			caFile,
		},
	}

	shell.RunCommand(t, cmdDeletePrevious)

	cmdGenerateKeyStore := shell.Command{
		Command: filepath.Join(repoCopyPath, "modules", "generate-key-stores", "generate-key-stores.sh"),
		Args: []string{
			"--key-store-path", keyStoreFile,
			"--trust-store-path", trustStoreFile,
			"--cert-path", certFile,
			"--ca-path", caFile,
			"--org", "Gruntwork",
			"--org-unit", "Engineering",
			"--city", "Phoenix",
			"--state", "AZ",
			"--country", "US",
			"--cert-common-name", domain,
			"--domain", domain,
			"--ip", "127.0.0.1",
			"--out-cert-key-path", keyFile,
		},
		Env: map[string]string{
			"KEY_STORE_PASSWORD":   password,
			"TRUST_STORE_PASSWORD": password,
		},
	}

	shell.RunCommand(t, cmdGenerateKeyStore)
}

func (k *keystore) getTlsConfig(t *testing.T) *tls.Config {
	caCert, err := ioutil.ReadFile(k.CaFile)
	if err != nil {
		t.Fatalf("Failed to read CA file %s due to error: %v", k.CaFile, err)
	}

	caCertPool := x509.NewCertPool()
	caCertPool.AppendCertsFromPEM(caCert)

	return &tls.Config{
		RootCAs:            caCertPool,
		InsecureSkipVerify: true,
	}
}

func downloadGenerateKeystoreScript(t *testing.T, downloadLocation string) {
	cmdClearDestination := shell.Command{
		Command: "rm",
		Args: []string{
			"-rf",
			downloadLocation,
		},
	}
	shell.RunCommand(t, cmdClearDestination)

	cmdClone := shell.Command{
		Command: "git",
		Args: []string{
			"clone",
			// Uncomment the following lines in order to force using
			// a specific branch.
			//"--single-branch",
			//"-b", "<__BRANCH_NAME_HERE__>",
			"https://github.com/gruntwork-io/package-kafka.git",
			downloadLocation,
		},
	}

	shell.RunCommand(t, cmdClone)
}

func exportCertAndKeyFromJks(t *testing.T, tlsCert *keystore, certAlias string, outputPath string, outputCertKey string) (string, string, string) {
	//https://serverfault.com/questions/715827/how-to-generate-key-and-crt-file-from-jks-file-for-httpd-apache-server

	storePass := "password"
	//keytool -exportcert -alias localhost -keystore elk.server.keystore.jks -rfc -file cert.pem
	certFileName := fmt.Sprintf("%s.pem", certAlias)
	certFilePath := fmt.Sprintf("%s/%s", outputPath, certFileName)
	cmdExportCert := shell.Command{
		Command: "keytool",
		Args: []string{
			"-exportcert",
			"-alias",
			certAlias,
			"-keystore",
			tlsCert.KeyStorePath,
			"-storepass",
			storePass,
			"-rfc",
			"-file",
			certFilePath,
		},
	}

	shell.RunCommand(t, cmdExportCert)

	//keytool -importkeystore -srckeystore mycert.jks -destkeystore keystore.p12 -deststoretype PKCS12
	cmdExportKey := shell.Command{
		Command: "keytool",
		Args: []string{
			"-importkeystore",
			"-srckeystore",
			tlsCert.KeyStorePath,
			"-destkeystore",
			outputCertKey,
			"-srcstorepass",
			storePass,
			"-deststorepass",
			storePass,
			"-deststoretype",
			"PKCS12",
		},
	}

	shell.RunCommand(t, cmdExportKey)

	//convert PKCS12 key to unencrypted PEM:
	//openssl pkcs12 -in keystore.p12  -nodes -nocerts -out mydomain.key
	keyFileName := fmt.Sprintf("%s.key", certAlias)
	keyFilePath := fmt.Sprintf("%s/%s", outputPath, keyFileName)
	cmdConvertKey := shell.Command{
		Command: "openssl",
		Args: []string{
			"pkcs12",
			"-in",
			outputCertKey,
			"-nodes",
			"-nocerts",
			"-password",
			fmt.Sprintf("pass:%s", storePass),
			"-out",
			keyFilePath,
		},
	}
	shell.RunCommand(t, cmdConvertKey)

	//convert PKCS12 key to unencrypted PEM:
	//openssl pkcs12 -in keystore.p12  -nodes -nocerts -out mydomain.key
	p8KeyFileName := fmt.Sprintf("%s.p8", certAlias)
	p8KeyFilePath := fmt.Sprintf("%s/%s", outputPath, p8KeyFileName)
	cmdConvertKeyP8 := shell.Command{
		Command: "openssl",
		Args: []string{
			"pkcs8",
			"-in",
			keyFilePath,
			"-topk8",
			"-nocrypt",
			"-out",
			p8KeyFilePath,
		},
	}
	shell.RunCommand(t, cmdConvertKeyP8)

	shell.RunCommand(t, shell.Command{Command: "rm", Args: []string{outputCertKey}})
	return certFilePath, keyFilePath, p8KeyFilePath
}

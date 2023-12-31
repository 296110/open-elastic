'use strict';

const http = require('http');
const https = require('https');

const ELASTICSEARCH_DNS = process.env.ELASTICSEARCH_DNS || "localhost"
const ELASTICSEARCH_PORT = process.env.ELASTICSEARCH_PORT || 9200;
const REPOSITORY = process.env.REPOSITORY;
const S3_BUCKET = process.env.BUCKET;
const PROTOCOL = process.env.PROTOCOL || "http";
const REGION = process.env.S3_BUCKET_AWS_REGION || "us-east-1";

// Ignore TLS checks for self signed CA if protocol is HTTPS
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

exports.handler = function (event, context, callback) {

  const makeHttpRequest = function (path, method, body, cb) {
    let client = PROTOCOL == "https" ? https : http;

    let headers = {
      'Content-Type': 'application/json',
      'Content-Length': body.length
    };

    const request = client.request({
      host: ELASTICSEARCH_DNS,
      port: ELASTICSEARCH_PORT,
      path: path,
      method: method,
      headers: headers
    }, function (response) {
      let data = '';

      response.on('data', (chunk) => {
        data += chunk;
      });

      response.on('end', () => {
        cb(response.statusCode, data);
      });

      response.on('error', (err) => {
        callback(err, "Error making request");
        return;
      });
    });

    request.write(body);
    request.end();
  };

  // Make-shift GUID function, from accepted answer: https://stackoverflow.com/questions/105034/create-guid-uuid-in-javascript
  const guid = function () {
    function s4() {
      return Math.floor((1 + Math.random()) * 0x10000)
        .toString(16)
        .substring(1);
    }
  
    return s4() + s4() + '-' + s4() + '-' + s4() + '-' + s4() + '-' + s4() + s4() + s4();
  };

  const backup = function () {
    const snapshot = `snapshot_${guid()}`;

    console.log("Backing up Elasticsearch " + ELASTICSEARCH_DNS);
    console.log(`Saving snapshot: ${snapshot}`);

    const path = `/_snapshot/${encodeURIComponent(REPOSITORY)}/${encodeURIComponent(snapshot)}?wait_for_completion=false`
    makeHttpRequest(path, 'PUT', '', function (statusCode, responseBody) {
      if (statusCode !== 200) {
        callback(responseBody, `Failed to backup cluster: ${responseBody}`);
      } else {
        callback(null, `Backup was successful: ${responseBody}`);
      }
    });
  };

  console.log(`Using protocol: ${PROTOCOL}`);

  const path = `/_snapshot/${encodeURIComponent(REPOSITORY)}`;
  makeHttpRequest(path, 'GET', '', function (statusCode, responseBody) {
    if (statusCode !== 200) {
      console.log(`Creating Elasticsearch backup repository: ${REPOSITORY}`);

      const requestBody = JSON.stringify({
        type: "s3",
        settings: {
          bucket: S3_BUCKET,
          region: REGION
        }
      });

      makeHttpRequest(path, 'PUT', requestBody, function (status, responseBody) {
        if (status !== 200) {
          callback(responseBody, `Failed to create repository ${responseBody}`);
        } else {
          console.log(`Backup repository '${REPOSITORY}' created successfully`);
          backup();
        }
      });
    } else {
      console.log(`Backup repository '${REPOSITORY}' already exists`);
      backup();
    }
  });
};

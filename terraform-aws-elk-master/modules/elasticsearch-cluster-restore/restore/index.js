'use strict';

const http = require('http');
const https = require('https');
const AWS = require('aws-sdk');

const ELASTICSEARCH_DNS = process.env.ELASTICSEARCH_DNS || "localhost"
const ELASTICSEARCH_PORT = process.env.ELASTICSEARCH_PORT || 9200;
const CLOUDWATCH_EVENT_RULE_NAME = process.env.CLOUDWATCH_EVENT_RULE_NAME;
const NOTIFICATION_FUNCTION_NAME = process.env.NOTIFICATION_FUNCTION_NAME;
const REPOSITORY = process.env.REPOSITORY;
const S3_BUCKET = process.env.BUCKET;
const PROTOCOL = process.env.PROTOCOL || "http";
const REGION = process.env.AWS_REGION || "us-east-1";

// Ignore TLS checks for self signed CA if protocol is HTTPS
process.env.NODE_TLS_REJECT_UNAUTHORIZED = "0";

exports.handler = function (event, context, callback) {

  const makeHttpRequest = function (path, method, body, cb) {
    let client = PROTOCOL == "https" ? https : http;

    const headers = {
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

  const restore = function () {
    console.log(`Restoring snapshot '${event.snapshotId}' to ${ELASTICSEARCH_DNS}`);

    const path = `/_snapshot/${encodeURIComponent(REPOSITORY)}/${encodeURIComponent(event.snapshotId)}/_restore?wait_for_completion=false`;
    makeHttpRequest(path, 'POST', '', function (statusCode, responseBody) {
      if (statusCode != 200) {
        callback(null, `Failed to restore snapshot: ${responseBody}`);
      } else {
        // Add snapshot ID to notification lambda environment variables
        const lambda = new AWS.Lambda({ region: REGION });
        var params = {
          FunctionName: NOTIFICATION_FUNCTION_NAME,
          Environment: {
            Variables: {
              'ELASTICSEARCH_DNS': ELASTICSEARCH_DNS,
              'ELASTICSEARCH_PORT': ELASTICSEARCH_PORT,
              'REPOSITORY': REPOSITORY,
              'PROTOCOL': PROTOCOL,
              'CLOUDWATCH_EVENT_RULE_NAME': CLOUDWATCH_EVENT_RULE_NAME,
              'SNAPSHOT_ID': event.snapshotId
            }
          }
        }

        lambda.updateFunctionConfiguration(params, function(err, data) {
          if (err)
            callback(err, 'An error occurred when updating notification lambda function env vars');
        });

        // Enable notification lambda Cloudwatch Event schedule
        const cw = new AWS.CloudWatchEvents({ region: REGION });
        params = {
          Name: CLOUDWATCH_EVENT_RULE_NAME,
          ScheduleExpression: 'rate(5 minutes)',
          State: 'ENABLED'
        };

        cw.putRule(params, function(err, data) {
          if (err)
            console.log('An error occurred when enabling Cloudwatch event rule', err);
        });

        callback(null, 'Restore operation started');
      }
    });
  };

  console.log(`Using protocol: ${PROTOCOL}`);

  const path = `/_snapshot/${encodeURIComponent(REPOSITORY)}`;
  makeHttpRequest(path, 'GET', '', function (statusCode, responseBody) {
    if (statusCode != 200) {
      console.log(`Creating Elasticsearch backup repository: ${REPOSITORY}`);

      const requestBody = JSON.stringify({
        type: "s3",
        settings: {
          bucket: S3_BUCKET,
          region: REGION
        }
      });

      makeHttpRequest(path, 'PUT', requestBody, function (status, responseBody) {
        if (status != 200) {
          callback(null, `Failed to create repository ${responseBody}`);
        } else {
          console.log(`Backup repository '${REPOSITORY}' created successfully`);
          restore();
        }
      });
    } else {
      console.log(`Backup repository '${REPOSITORY}' already exists`);
      restore();
    }
  });
};

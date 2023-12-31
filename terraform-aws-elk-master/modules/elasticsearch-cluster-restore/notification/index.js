'use strict';

const http = require('http');
const https = require('https');
const AWS = require('aws-sdk');

const ELASTICSEARCH_DNS = process.env.ELASTICSEARCH_DNS || "localhost"
const ELASTICSEARCH_PORT = process.env.ELASTICSEARCH_PORT || 9200;
const CLOUDWATCH_EVENT_RULE_NAME = process.env.CLOUDWATCH_EVENT_RULE_NAME;
const REPOSITORY = process.env.REPOSITORY;
const PROTOCOL = process.env.PROTOCOL || "http";
const REGION = process.env.AWS_REGION || "us-east-1";
const SNAPSHOT_ID = process.env.SNAPSHOT_ID;

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

  const checkStatus = function () {
    console.log(`Checking status of restore with snapshot '${SNAPSHOT_ID}' to ${ELASTICSEARCH_DNS}`);

    const path = `/_snapshot/${encodeURIComponent(REPOSITORY)}/${encodeURIComponent(SNAPSHOT_ID)}`;
    makeHttpRequest(path, 'GET', '', function (statusCode, responseBody) {
      if (statusCode != 200) {
        callback(responseBody, `Failed to get status of snapshot: ${SNAPSHOT_ID}`);
      } else {
        const status = JSON.parse(responseBody).snapshots[0].state;
        if (status === 'IN_PROGRESS') {
          console.log('Restore operation still in progress');
          callback(null, "Restore operation still in progress");
        } else {
          console.log(`Restore operation completed with status: ${status}. ${responseBody[0]}`);
          // Disable notification lambda Cloudwatch Event schedule
          const cw = new AWS.CloudWatchEvents({ region: REGION });
          var params = {
            Name: CLOUDWATCH_EVENT_RULE_NAME,
            ScheduleExpression: 'rate(5 minutes)',
            State: 'DISABLED'
          };

          cw.putRule(params, function (err, data) {
            if (err)
              console.log('An error occurred when enabling Cloudwatch event rule', err);
          });

          callback(null, `Restore operation completed with status: ${status}. ${responseBody[0]}`)
        }
      }
    });
  };

  checkStatus();

};

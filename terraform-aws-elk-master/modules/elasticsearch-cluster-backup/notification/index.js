'use strict';

const AWS = require('aws-sdk');

const REGION = process.env.AWS_REGION || "us-east-1";
const METRIC_NAME = process.env.CLOUDWATCH_METRIC_NAME;
const METRIC_NAMESPACE = process.env.CLOUDWATCH_METRIC_NAMESPACE;
const METRIC_VALUE = 1;

exports.handler = function (event, context, callback) {

  const putMetric = function () {
    const cw = new AWS.CloudWatch({ region: REGION });

    const params = {
      MetricData: [
        {
          MetricName: METRIC_NAME,
          Unit: 'Count',
          Value: METRIC_VALUE
        },
      ],
      Namespace: METRIC_NAMESPACE
    };

    cw.putMetricData(params, function (err, data) {
      if (err) {
        callback(err, "Error putting metric");
      } else {
        console.log("Successfully updated metric", data);
      }
    });
  };

  const filename = event.Records[0].s3.object.key;
  if (filename.startsWith('index-')) {
    console.log("Backup was successful, updating metric");
    putMetric();
    callback(null, "Success");
    return;
  }

  callback(null, `Found file '${filename}', ignoring in favor of one prefixed with 'index-'`);
};

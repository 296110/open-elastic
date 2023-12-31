# Elasticsearch Cluster Restore

This folder contains a [Terraform](https://www.terraform.io/) module to restore backups of an [Elasticsearch](https://www.elastic.co/products/kibana) cluster from snapshots saved in S3. The module is a lambda function that calls the Elasticsearch API to perform cluster restore tasks documented [here](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-snapshots.html);

## How do you use this module?

The module works by deploying an AWS Lambda function that can be manually invoked via the AWS Console. This module restores snapshots previously saved to S3 with the help of the [repository-s3](https://www.elastic.co/guide/en/elasticsearch/plugins/current/repository-s3-repository.html) plugin.

```hcl
module "es_cluster_restore" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/elasticsearch-cluster-restore?ref=<VERSION>"

  name                = "..."
  elasticsearch_dns   = "..."
  repository          = "..."
  bucket              = "..."
  region              = "..."
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of this module. The double slash (`//`) is intentional and required. Terraform uses it to specify subfolders within a Git repo (see [module sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in this repo. That way, instead of using the latest version of this module from the `master` branch, which will change every time you run Terraform, you're using a fixed version of the repo.

* `name`: This parameter specifies the name assigned to the lambda function.

* `elasticsearch_dns`: The DNS used to access the Elasticsearch cluster, must be reachable on port `9200` or use the `elasticsearch_port` parameter to configure a custom port.

* `respository`: The name to assign to the repository where backups are stored

* `bucket`: The _existing_ S3 bucket where snapshots are stored.

* `region`: The region where the S3 bucket exists.

You can find the other parameters in [vars.tf](vars.tf).

Check out the [examples folder](/examples/elasticsearch-only-cluster) for working sample code.

## Restoring snapshots

All the above section does, is deploy the Lambda function that contains the cluster restore code. You'll need to actually invoke that function with the right snapshot ID to perform a restore. The backup module generates an ID for each snapshot it saves to S3 and this can be located in its CloudWatch logs; grep for string `"Saving snapshot: <SNAPSHOT>"`. Snapshot index files stored along side the backup data in S3 also contain this information.

Performing a restore is quite straightforward at this point, it involves manually invoking the Lambda function via the [web interface](https://us-east-2.console.aws.amazon.com/lambda/home) or [AWS CLI](https://docs.aws.amazon.com/lambda/latest/dg/with-on-demand-custom-android-example-upload-deployment-pkg.html#walkthrough-on-demand-custom-android-events-adminuser-create-test-function-upload-zip-test-manual-invoke). The ID of the snapshot to restore is specified in the event data passed to the Lambda:

```json
{
  "snapshotId": "<SNAPSHOT>"
}
```

### Restoring to a different cluster

Snapshots created from a cluster can be restored to a completely different cluster, this module will transparently setup a backup repository (backed by the S3 cluster containing the snapshots) on the new cluster and the standard restore process described above will work.

You should be mindful of the difference in versions of the Elasticsearch cluster the snapshots were created with and the cluster it's being restored to. The [documentation](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-snapshots.html#modules-snapshots) contains more information on the compatiblity matrix and how to upgrade snapshots created with older versions of Elasticsearch.

### Restore Notification

The time it takes to restore a snapshot is dependent on the volume of data within that snapshot. However, since the restore module is implemened as a Lambda function which has a maximum execution time of 5 minutes a separate notification Lambda is kicked off. The notification Lambda will check the status of the restore operation and re-invoke itself until the operation is complete. The notification Lambda continiously logs the status of the restore operation to Cloudwatch.

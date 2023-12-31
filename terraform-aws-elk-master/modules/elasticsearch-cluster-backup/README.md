# Elasticsearch Cluster Backup

This folder contains a [Terraform](https://www.terraform.io/) module to take and backup snapshots of an [Elasticsearch](https://www.elastic.co/products/kibana) cluster to an S3 bucket. The module is a scheduled lambda function that calls the Elasticsearch API to perform snapshotting and backup related tasks documented [here](https://www.elastic.co/guide/en/elasticsearch/reference/current/modules-snapshots.html);

## Terminologies

* **Snapshot**: A snapshot represents the current state of the indices in an Elasticsearch cluster. This is the information stored in a backup repository.
* **Repository**: A repository is an Elasticsearch abstraction over a storage medium like a Shared File System, S3 Bucket, HDFS etc. It's used to identify where snapshot files are stored and doesn't contain any snapshots itself.

## How do you use this module?

The module works by deploying an AWS Lambda function that performs backups on a configurable schedule. This module saves all snapshots to S3 with the help of the [repository-s3](https://www.elastic.co/guide/en/elasticsearch/plugins/current/repository-s3-repository.html) plugin.

```hcl
module "es_cluster_backup" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/elasticsearch-cluster-backup?ref=<VERSION>"

  name                = "..."
  schedule_expression = "..."
  elasticsearch_dns   = "..."
  repository          = "..."
  bucket              = "..."
  region              = "..."
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of this module. The double slash (`//`) is intentional and required. Terraform uses it to specify subfolders within a Git repo (see [module sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in this repo. That way, instead of using the latest version of this module from the `master` branch, which will change every time you run Terraform, you're using a fixed version of the repo.

* `name`: This parameter specifies the name assigned to the lambda function.

* `schedule_expression`: A CloudWatch schedule expression or valid cron expression to specify how often a backup should be done. E.g. `cron(0 20 * * ? *)`, `rate(5 minutes)`.

* `elasticsearch_dns`: The DNS used to access the Elasticsearch cluster, must be reachable on port `9200` or use the `elasticsearch_port` parameter to configure a custom port.

* `respository`: The name to assign to the repository that'll be created for all backups

* `bucket`: The S3 bucket where snapshots will be stored. The bucket must exist as it will not be created.

* `region`: The region where the S3 bucket exists.

You can find the other parameters in [vars.tf](vars.tf).

Check out the [examples folder](/examples/elasticsearch-only-cluster) for working sample code.

## Taking Backups

Cluster snapshots are incremental. The first snapshot is always a full dump of the cluster and subsequent ones are a delta between the current state of the cluster and the previous snapshot. Snapshots are typically contained in `.dat` files stored in the storage medium (in this case S3) the repository points to.

### CPU and Memory Usage

Snapshots are usually run on a single node which automatically co-ordinates with other nodes to ensure completenss of data. Backup of a cluster with a large volume of data will lead to high CPU and memory usage on the node performing the backup. This module makes backup requests to the cluster through the load balancer which routes the request to one of the nodes, during backup, if the selected node is unable to handle incoming requests the load balancer will direct the request to other nodes.

### Frequency of Backups

How often you make backups depends entirely on the size of your deployment and the importance of your data. Larger clusters with high volume usage will typically need to be backed up more frequently than low volume clusters because of the amount of data change between snapshots. It's a safe bet to start off running backups on a nightly schedule and then continually tweak the schedule based on the demands of your cluster.

### Backup Notification

The time it takes to backup a cluster is dependent on the volume of data. However, since the backup module is implemened as a Lambda function which has a maximum execution time of 5 minutes a separate notification Lambda is kicked off. A Cloudwatch metric is incremented any time the notification lambda confirms that a backup occured and an alarm connected to that metric notifies you where or not it was updated.

## Restoring Backups

Restoring snapshots is handled by the [elasticsearch-cluster-restore module](../elasticsearch-cluster-restore).

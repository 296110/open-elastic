# Testing strategy

### Elasticsearch-cluster

- Build /examples/elasticsearch-ami
- Launch /modules/elasticsearch-cluster
- Write a bunch of data to cluster 
- Run a query and check for expected value
- Additional items to test:
  - keystore generation for sensitive config
  - deploy an update to the cluster, and confirm it rolls out with no downtime.

### Elasticsearch-backup-restore
- Build /examples/elasticsearch-ami
- Launch /modules/elasticsearch-cluster
- Write a bunch of data to cluster 
- Run a query and check for expected value
- Backup cluter to S3
- Destroy cluster
- Launch new cluster from backup
- Run a query and check for expected value

### ElastAlert

- Build /examples/elasticsearch-ami
- Launch /modules/elasticsearch-cluster with an ElastAlert rule that is easy to trigger and which sends an alert to SNS
- Write a bunch of data to cluster to trigger the ElastAlert rule
- Check SNS for message

### Kibana

- Build /examples/elasticsearch-ami with Kibana
- Launch /modules/elasticsearch-cluster
- Attempt to curl `<public-ip>:5601/`. If HTTP 200, test passes.

### Logstash

- Build /examples/elasticsearch-ami with Logstash
- Launch /modules/elasticsearch-cluster
- Write a file with dummy log data to `/some/path/scanned/by/logstash`
- Check Elasticsearch for the presence of said data
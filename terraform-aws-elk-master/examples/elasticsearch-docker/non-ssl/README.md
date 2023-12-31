# Local testing

Sometimes it is convenient to use docker for testing out the various scripts in the `modules` folder 
without having to wait for an AMI to build and a bunch of EC2 Instances to boot up (and not having to pay for running those instances).

## Quick start

To build the Docker Image:

1. Follow instructions [here](/examples/elk-amis/README.md) and build Docker images for
Elasticsearch with or without HTTPS enabled.
1. Edit the `.env` file and make sure that the proper `CONTAINER_BASE_NAME` is set
depending on whether you are testing Elasticsearch over HTTP or HTTPS

```
   # For testing over HTTP use:
   CONTAINER_BASE_NAME=elasticsearch
   ```
```
   # For testing over HTTPS use:
   CONTAINER_BASE_NAME=elasticsearch-ssl
   ```

To start docker:

1. Run `docker-compose up`
1. You should now be able to go to access elasticsearch at: [http://localhost:9200/](http://localhost:9200/)
# ElastAlert IAM Policies

This folder contains a [Terraform](https://www.terraform.io/) module that defines the IAM Policies used by an
[ElastAlert](https://github.com/Yelp/elastalert) cluster. These policies are defined in a separate module
so that you can add them to any existing IAM Role. 

## Quick start

Let's say you want to deploy ElastAlert using the [elastalert 
module](/modules/elastalert): 

```hcl
module "elastalert" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/elastalert?ref=<VERSION>"

  # ... (other params omitted) ...
}
```

You can attach the IAM policies to this cluster as follows:

```hcl
module "elastalert_iam_policies" {
  # TODO: replace <VERSION> with the latest version from the releases page: https://github.com/gruntwork-io/terraform-aws-elk/releases
  source = "github.com/gruntwork-io/terraform-aws-elk//modules/elastalert-iam-policies?ref=<VERSION>"

  iam_role_id = module.elasticsearch.iam_role_id
}
```

Note the following parameters:

* `source`: Use this parameter to specify the URL of this module. The double slash (`//`) is intentional 
  and required. Terraform uses it to specify subfolders within a Git repo (see [module 
  sources](https://www.terraform.io/docs/modules/sources.html)). The `ref` parameter specifies a specific Git tag in 
  this repo. That way, instead of using the latest version of this module from the `master` branch, which 
  will change every time you run Terraform, you're using a fixed version of the repo.

* `iam_role_id`: Use this parameter to specify the ID of the IAM Role to which the policies in this module
  should be added.

  
You can find the other parameters in [variables.tf](variables.tf).

Check out the [elk-multi-cluster example](/examples/elk-multi-cluster) for working sample code.

## A collection of sample github-action workflows for integrating with IBM Cloudability Governance

### /single-deployment
Sample workflow for a case when repository contains IaC code for a single deployment 

### /multiple-deploymments 
Sample workflow for a case when IaC code for multiple deployment stacks is contained within a single repository. For eg a multi-region deployment of a single micro-service. This example demonstrates how to trigger Cloudability Governance workflow for a specific region.

### /terragrunt-run-all
Sample workflow for a case when using `terragrunt run-all plan` to generate plan file for multiple deployments. It also uses github matrix construct to handle multiple deployments with a single workflow file.
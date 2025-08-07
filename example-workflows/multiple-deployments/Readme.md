## Structure

Assuming that an IaC repository contains code for multiple regions contained within different directories and some common modules - 


```
    /
    | ----- /common
                |
                 /aws
                    | ----- resources.tf
    |
    | -----    /regions
                |
               /region-a
                    | ----- main.tf
                |
               /region-b
                    | ----- main.tf

```

In this workflow example, we only run the Governance workflow, when a PR is created (or updated) with files that affect a specific region

```
on:
  pull_request:
    types: [opened, reopened, synchronize]
    paths:
    - 'common/aws/**' # common module used across deployments
    - 'envs/region-a/**' # specific module against which to run Governance Action
```
ensures that if a pull request makes a change to `envs/region-a` then the workflow action will get triggered. 


### Account setup 

Providing a proider account mapping allows Cloudability Governance to consider any custom pricing that might be available for an account when giving cost estimations. 

This structure is a mapping of provider alias to the corresponding AccountID and Cloud vendor.

The wildcard `*` indicates the default account information to use if a specific providers information is not set. 

```
- name: Run Cloudability Cost Estimation
        uses: IBM/ibm-cloudability-governance/actions/cost-estimation@v0.1.3
        continue-on-error: true
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}
          cloudability-host: ${{ vars.CLDY_HOST }}
          fd-env-id: ${{ vars.FD_ENV_ID }}
          deployment-name: "governance-demo-prod"
          provider-accounts: |
             {
              "module.database:aws_region_a": {
                "account_id": "${{ secrets.AWS_ACCOUNT_REGION_A }}", 
                "vendor": "aws"
              },
              "*": {
                "account_id": "${{ secrets.SECONDARY_AWS_ACCOUNT_ID }}", 
                "vendor": "aws"
              }
            }
          tf-plan: "envs/prod/tfplan.json"
          resource-usage: ${{ steps.usage.outputs.USAGE_PATH }}
```

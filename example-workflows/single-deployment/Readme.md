## Structure

Assuming that an IaC repository contains code for a single deployment


```
    /
    | ----- main.tf

```

In this workflow example, we initiate Governance worflow when a pull-request is created or updated. 

```
on:
  pull_request:
    types: [opened, reopened, synchronize]
```
ensures that if a pull request is created/updated then the workflow action will get triggered. 


### Account setup 

Providing a proider account mapping allows Cloudability Governance to consider any custom pricing that might be available for an account when giving cost estimations. 

This structure is a mapping of provider alias to the corresponding AccountID and Cloud vendor. 

The wildcard `*` indicates the default account information to use if a specific providers information is not set. 

```
- name: Run Cloudability Cost Estimation
        uses: IBM/ibm-cloudability-governance/actions/cost-estimation@v0.2.x
        continue-on-error: true
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}
          cloudability-host: ${{ vars.CLDY_HOST }}
          fd-env-id: ${{ vars.FD_ENV_ID }}
          deployment-name: "governance-demo-prod"
          provider-accounts: |
            {
              "aws_usw2": {
                "account_id": "${{ secrets.AWS_ACCOUNT_ID }}", 
                "vendor": "aws"
              },
              "*": {
                "account_id": "${{ secrets.SECOND_AWS_ACCOUNT_ID }}", 
                "vendor": "aws"
              }
            }
          tf-plan: "tfplan.json"
          resource-usage: ${{ steps.usage.outputs.USAGE_PATH }}
```

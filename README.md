# ibm-cloudability-governance-action-template

This is an Apache-2.0 licensed, github-action template library for integrating [IBM Cloudability Governance](https://www.apptio.com/products/cloudability/governance/)

## Workflow Overview

### Setup

#### Terraform Plan Output

Cloudability Governance requires the Terraform plan output to evaluate proposed Infrastructure changes in a pull request. 

Given the diveristy of ways in which infrastructure code can be setup. The workflow steps just expect a `tfplan.json` file with the plan output to be present during the lifetime of the workflow. Customers can configure this based on how on their terraform code is organized. 

Here are some different sample setups and corresponding ways to generate and add a terraform plan output in the workflow 

> In our examples we have used, [AWS Credentials Github action](https://github.com/aws-actions/configure-aws-credentials) to fetch AWS credentials to be able to run terraform plan. Github secrets can be used to store the ARN of the AWS_ROLE to be used for this purpose. While this is the recommended approach, Customers can use others alternatives as well. 

> **Note**: `Deployment` here refers to all infrastructure resources that would be present together in a single Terraform plan output. 

<details><summary> A repository with IaC code for a single deployment</summary>

```
name: Demo Pipeline
run-name: Deployment
on:
  pull_request:
    types: [opened, reopened, synchronize]
    paths:
    - '**.tf'
    - 'usage.yaml'
    - '!README.md'
    
jobs:
  terraform:
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    defaults:
     run:
       shell: bash
       # Can change to specific directory here where Terraform files are present
       working-directory: ./
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
    
      - name: Setup AWS credentials
        uses: aws-actions/configure-aws-credentials@v4.1.0
        with:
          aws-region: us-west-2
          role-to-assume: ${{ secrets.AWS_ROLE }}
          role-session-name: ${{ github.run_id }}
    
      - name: Setup Terraform with specified version on the runner
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.10.5
          terraform_wrapper: false
    
      - name: Terraform init
        id: init
        run: terraform init
    
      - name: Terraform plan
        id: plan
        run: |
          terraform plan -lock=false -input=false -out=tfplan
          terraform show -json tfplan > tfplan.json
        continue-on-error: true
    
      - name: Redact secrets from tfplan
        run: |
          sed -i 's/"password":"[^"]*"/"password":""/g' tfplan.json
          sed -i 's/"secret_string":"{[^}]*}"/"secret_string":""/g' tfplan.json
      
      - name: Terraform Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1
```
</details></br>

<details><summary>A repository with IaC code for multiple deployments across multiple regions, with a single workflow</summary>

```
name: Demo Pipeline
run-name: Deployment
on:
  pull_request:
    types: [opened, reopened, synchronize]
    paths:
    - '**.tf'
    - '**/usage.yaml'
jobs:
  setup:
    name: setup
    runs-on: ubuntu-latest
    permissions:
      id-token: write
      contents: read
    outputs:
      matrix: ${{ steps.set-deployment-stacks-matrix.outputs.matrix }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Get list of deployment stacks under 'stack' folder
        id: set-deployment-stacks-matrix
        run: |
          dirs=$(find stack -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
          echo "List of Deployment stacks:"
          echo "$dirs"

          # Convert to JSON array
          deployment_stacks_json=$(printf '%s\n' $dirs | jq -R . | jq -s .)
          echo "Deployment stacks matrix JSON: $deployment_stacks_json"
          
          #echo "matrix=$deployment_stacks_json" >> $GITHUB_OUTPUT
          echo "matrix<<EOF" >> $GITHUB_OUTPUT
          echo "$deployment_stacks_json" >> $GITHUB_OUTPUT
          echo "EOF" >> $GITHUB_OUTPUT
          
  cloudability-governance:
    needs: setup
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      checks: write
    strategy:
      matrix:
        deployment-stack: ${{ fromJson(needs.setup.outputs.matrix) }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        
      - name: Setup AWS credentials
        uses: aws-actions/configure-aws-credentials@v4.1.0
        with:
          aws-region: us-west-2
          role-to-assume: ${{ secrets.AWS_ROLE }}
          role-session-name: ${{ github.run_id }}

      - name: Setup Terraform with specified version on the runner
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.10.5
          terraform_wrapper: false

      - name: Install js-yaml
        id: js-yaml
        run: npm install -g js-yaml

      - name: Generate tfplan in the deployment stack directory
        id: tf
        run: |
          cd stack/${{ matrix.deployment-stack }}
          echo "Current Directory: $(pwd)"
          terraform init
          terraform plan -lock=false -input=false -out=tfplan
          terraform show -json tfplan > tfplan.json
        continue-on-error: false

      - name: Redact secrets from tfplan
        run: |
          sed -i 's/"password":"[^"]*"/"password":""/g' tfplan.json
          sed -i 's/"secret_string":"{[^}]*}"/"secret_string":""/g' tfplan.json
      
      - name: Terraform Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1
```
</details></br>

<details><summary>A repository with IaC code for multiple deployments across multiple regions, with multiple workflows</summary>

```
name: Demo Pipeline
run-name: Deployment
on:
  pull_request:
    types: [opened, reopened, synchronize]
    paths:
    - 'common/aws/**'
    - 'stack/beta/**'
jobs:
  cloudability-governance:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      pull-requests: write
      checks: write
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4
        
      - name: Setup AWS credentials
        uses: aws-actions/configure-aws-credentials@v4.1.0
        with:
          aws-region: us-west-2
          role-to-assume: ${{ secrets.AWS_ROLE }}
          role-session-name: ${{ github.run_id }}

      - name: Setup Terraform with specified version on the runner
        uses: hashicorp/setup-terraform@v3
        with:
          terraform_version: 1.10.5
          terraform_wrapper: false

      - name: Install js-yaml
        id: js-yaml
        run: npm install -g js-yaml

      - name: Generate tfplan in the beta directory
        id: tf
        run: |
          cd stack/beta
          echo "Current Directory: $(pwd)"
          terraform init
          terraform plan -lock=false -input=false -out=tfplan
          terraform show -json tfplan > tfplan.json
        continue-on-error: false

      - name: Redact secrets from tfplan
        run: |
          sed -i 's/"password":"[^"]*"/"password":""/g' tfplan.json
          sed -i 's/"secret_string":"{[^}]*}"/"secret_string":""/g' tfplan.json
      
      - name: Terraform Plan Status
        if: steps.plan.outcome == 'failure'
        run: exit 1
``` 
</details></br>


Terraform Plan could also be uploaded as an artifact in a separate job

<details><summary>Terraform plan as artifact</summary>

```
      - name: Download tfplan
        uses: actions/download-artifact@v4
        with:
          name: tfplan
```
</details>

#### Cloudbility Credentials 

The workflow steps require a Frontdoor token to authenticate Cloudability Governance APIs.
`Get Frontdoor token` step in the template retrieves and sets a short-lived token, using Frontdoor API Key and Secret. 

This requires setting repository Serets with the variables -
 - FD_URL : Frontdoor instance to retrieve token from , eg https://frontdoor.apptio.com
 - FD_KEY : Key for the Frontdoor user
 - FD_SECRET : Secret for the Frontdoor user

>**Note**: Frontdoor has a default role `Cloudability Governance Automation User`. Key/Secret pair of an account with this role will have all the requisite permissions required for the workflow steps.

<details><summary><code>Get Frontdoor token</code></summary>

```
      - name: Get Frontdoor token
        uses: ibm/ibm-cloudability-governance-action-template/actions/frontdoor/login@v0.1.0
        with:
          fd-url: ${{ secrets.FD_URL }}
          fd-public-key: ${{ secrets.FD_KEY }}
          fd-secret-key: ${{ secrets.FD_SECRET }}
```
</details>

#### Metadata 

Metadata associated with a pull-request and and Cloudability Governance is required to capture Governance metrics for your Organization. 

`Get GitHub PR metadata` step in the template calls the Github API to fetch PR related metadata 

<details><summary><code>Get Github PR metadata</code></summary>

```
      - name: Get GitHub PR metadata
        uses: ibm/ibm-cloudability-governance-action-template/actions/github-info@v0.1.0
		with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}

```
</details></br>


`Cloudability Governance Metadata Retrieval` step in the template uses Cloudability API to fetch Governance configuration (project, deployment, pull request, github app installations) from Cloudability 


<details><summary><code>Cloudabilitty Governance Metadata Retrieval</code></summary>

```
 	  - name: Run Cloudability Governance Metadata Retrieval
        uses: ibm/ibm-cloudability-governance-action-template/actions/metadata@v0.1.0
        with:
          cloudability-host: ${{ secrets.CLOUDABILITY_HOST }}
          fd-env-id: ${{ secrets.FD_ENV_ID }}

```
</details></br>


This steps requires the Frontdoor Environment ID for your Cloudability Organization and the Cloudability Host. They can be set as Github secrets or variables 

- FD_ENV_ID (Frontdoor Environment Id) 
- CLOUDABILITY_HOST (example: https://api.cloudability.com)

#### Governance 

Governance consists of 3 components - 

`Cost Estimation` , `Policy Evaluation` and `Recommendations`.

We provide 3 separate action templates for each of these steps and they can be chosen as needed. 

>**Note**: `Frontdoor Token`,`Github Metadata` and `Cloudability Governance Metadata` are required for running any governance action. 

##### Cloud Provider Configuration

For running Governance actions, a `provider-accouts` input is needed. This is a map of [terraform provider key](https://developer.hashicorp.com/terraform/language/providers/configuration#provider-configuration-1) to a Cloud Vendor Account ID. This is neeeded to fetch the pricing information from the correct cloud vendor account. 

The provider key can either be a wildcard `*`, indicating that this account is the default for any provider keys in the terraform plan, or it can be the exact provider config key as represented in the `configuration.provider_config` map in the terraform plan json. 

>For example, if a provider with local name `aws_usw2` is defined in a module called “database” and the root terraform module is calling the `database` module, the provider key will be `module.database:aws_usw2`

Here are some sample setups for the 2 different scenarios - 

<details><summary><code>Governance actions for a deployment to a single cloud vendor account (using * as key in provider-accounts map)</code></summary>

```
      - name: Run Cloudability Cost Estimation
        uses: ibm/ibm-cloudability-governance-action-template/actions/cost-estimation@v0.1.0
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}
          cloudability-host: ${{ secrets.CLOUDABILITY_HOST }}
          fd-env-id: ${{ secrets.FD_ENV_ID }}
          deployment-name: "demo"
          provider-accounts: |
            {
              "*": {
                "account_id": "${{ secrets.AWS_ACCOUNT_ID }}", 
                "vendor": "aws"
              }
            }
          tf-plan: "tfplan.json"
          resource-usage: "usage.json"

      - name: Run Cloudability Governance Policy Evaluation
        uses: ibm/ibm-cloudability-governance-action-template/actions/policy-evaluation@v0.1.0
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}
          cloudability-host: ${{ secrets.CLOUDABILITY_HOST }}
          fd-env-id: ${{ secrets.FD_ENV_ID }}
          deployment-name: "demo"
          provider-accounts: |
            {
              "*": {
                "account_id": "${{ secrets.AWS_ACCOUNT_ID }}", 
                "vendor": "aws"
              }
            }
          tf-plan: "tfplan.json"
          resource-usage: "usage.json"

      - name: Run Cloudability Recommendation
        uses: ibm/ibm-cloudability-governance-action-template/actions/recommendation@v0.1.0
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}
          cloudability-host: ${{ secrets.CLOUDABILITY_HOST }}
          fd-env-id: ${{ secrets.FD_ENV_ID }}
          deployment-name: "demo"
          provider-accounts: |
            {
              "*": {
                "account_id": "${{ secrets.AWS_ACCOUNT_ID }}", 
                "vendor": "aws"
              }
            }
          tf-plan: "tfplan.json"
          resource-usage: "usage.json"

```
</details></br>


<details><summary><code>Governance actions for a deployment to multiple cloud vendor accounts (using fully qualified key name in provider-accounts map)</code></summary>

```
      - name: Run Cloudability Cost Estimation
        uses: ibm/ibm-cloudability-governance-action-template/actions/cost-estimation@v0.1.0
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}
          cloudability-host: ${{ secrets.CLOUDABILITY_HOST }}
          fd-env-id: ${{ secrets.FD_ENV_ID }}
          deployment-name: "demo"
          provider-accounts: |
            {
              "module.database:aws_usw2": {
                "account_id": "${{ secrets.AWS_ACCOUNT_ID }}", 
                "vendor": "aws"
              }
            }
          tf-plan: "tfplan.json"
          resource-usage: "usage.json"

      - name: Run Cloudability Governance Policy Evaluation
        uses: ibm/ibm-cloudability-governance-action-template/actions/policy-evaluation@v0.1.0
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}
          cloudability-host: ${{ secrets.CLOUDABILITY_HOST }}
          fd-env-id: ${{ secrets.FD_ENV_ID }}
          deployment-name: "demo"
          provider-accounts: |
            {
              "module.database:aws_usw2": {
                "account_id": "${{ secrets.AWS_ACCOUNT_ID }}", 
                "vendor": "aws"
              }
            }
          tf-plan: "tfplan.json"
          resource-usage: "usage.json"

      - name: Run Cloudability Recommendation
        uses: ibm/ibm-cloudability-governance-action-template/actions/recommendation@v0.1.0
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}
          cloudability-host: ${{ secrets.CLOUDABILITY_HOST }}
          fd-env-id: ${{ secrets.FD_ENV_ID }}
          deployment-name: "demo"
          provider-accounts: |
            {
              "module.database:aws_usw2": {
                "account_id": "${{ secrets.AWS_ACCOUNT_ID }}", 
                "vendor": "aws"
              }
            }
          tf-plan: "tfplan.json"
          resource-usage: "usage.json"

```
</details>

##### Usage Information

Governance actions can take an additional usage file mapping expected resource usage to their resource identifiers. This can be added as a YAML or json file. 
For YAML files, you can use [js-yaml](https://github.com/nodeca/js-yaml) and incorporate it within the workflow - 


<details><summary><code>Adding usage input </code></summary>

```
      - name: Install js-yaml
        id: js-yaml
        run: npm install -g js-yaml
      # Generate usage.json from usage.yaml file
      - name: Convert usage.yaml
        id: usage
        run: |
          js-yaml usage.yaml > usage.json
```
</details>
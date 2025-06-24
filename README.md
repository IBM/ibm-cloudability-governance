# ibm-cloudability-governance

This is an Apache-2.0 licensed, github-action template library for integrating [IBM Cloudability Governance](https://www.apptio.com/products/cloudability/governance/)

## Workflow Overview

### Setup

#### 1. Terraform Plan Output

Cloudability Governance requires the Terraform plan output to evaluate proposed infrastructure changes in a pull request. 


The workflow needs terraform plan output in json format (tfplan.json) as input. Given the diversity of ways in which infrastructure code can be setup, customers can configure this step based on how their terraform code is organized.

Terraform plan is not persisted in Cloudability servers but as a best practise for security, we recommend removing secrets and sensitive information from the terraform plan. The examples below demonstrate a possible way to do this. 

Here are some different sample setups and corresponding ways to generate and add a terraform plan output in the workflow.

> In our examples we have used [AWS Credentials Github action](https://github.com/aws-actions/configure-aws-credentials) to fetch AWS credentials to be able to run terraform plan. Github secrets can be used to store the ARN of the AWS_ROLE to be used for this purpose. While this is the recommended approach, customers can use other alternatives as well. 

> **Note**: `Deployment` here refers to all infrastructure resources that would be present together in a single Terraform plan output. 

<details><summary> A repository with IaC code for a single deployment</summary>

``` yaml
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
        continue-on-error: false
    
      - name: Redact secrets from tfplan
        run: |
          sed -i 's/"password":"[^"]*"/"password":""/g' tfplan.json
          sed -i 's/"secret_string":"{[^}]*}"/"secret_string":""/g' tfplan.json
```
</details></br>

Now assuming a directory structure for a single repository with multiple deployments
```
/infrastructure-repo
    |
    |--- /common
    |     |---/aws
    |           |--- resources.tf
    |     
    |--- /deployment
    |         |
    |         |--- /alpha
    |         |       |--- main.tf
    |         |
    |         |--- /beta
    |         |       |--- main.tf
```

<details><summary> Handling terraform plan for all deployments with a single workflow</summary>

``` yaml
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
      matrix: ${{ steps.set-deployment-matrix.outputs.matrix }}
    steps:
      - name: Checkout repository
        uses: actions/checkout@v4

      - name: Get list of deployments under 'deployment' folder
        id: set-deployment-matrix
        run: |
          dirs=$(find deployment -maxdepth 1 -mindepth 1 -type d -exec basename {} \;)
          echo "List of Deployments:"
          echo "$dirs"

          # Convert to JSON array
          deployments_json=$(printf '%s\n' $dirs | jq -R . | jq -s .)

          echo "Deployment matrix JSON: $deployments_json"
          echo "matrix<<EOF" >> $GITHUB_OUTPUT
          echo "$deployments_json" >> $GITHUB_OUTPUT
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
        deployment: ${{ fromJson(needs.setup.outputs.matrix) }}
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

      - name: Generate tfplan in the deployment directory
        id: tf
        run: |
          cd deployment/${{ matrix.deployment }}
          echo "Current Directory: $(pwd)"
          terraform init
          terraform plan -lock=false -input=false -out=tfplan
          terraform show -json tfplan > tfplan.json
        continue-on-error: false

      - name: Redact secrets from tfplan
        run: |
          sed -i 's/"password":"[^"]*"/"password":""/g' tfplan.json
          sed -i 's/"secret_string":"{[^}]*}"/"secret_string":""/g' tfplan.json
```
</details></br>

<details><summary>Handling terraform plan with one workflow for each deployment</summary>

``` yaml
name: Demo Pipeline
run-name: Deployment
on:
  pull_request:
    types: [opened, reopened, synchronize]
    paths:
    - 'common/aws/**'
    - 'deployment/beta/**' # Only triggers for the /beta Deployment
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

      - name: Generate tfplan in the beta directory
        id: tf
        run: |
          cd deployment/beta
          echo "Current Directory: $(pwd)"
          terraform init
          terraform plan -lock=false -input=false -out=tfplan
          terraform show -json tfplan > tfplan.json
        continue-on-error: false

      - name: Redact secrets from tfplan
        run: |
          sed -i 's/"password":"[^"]*"/"password":""/g' tfplan.json
          sed -i 's/"secret_string":"{[^}]*}"/"secret_string":""/g' tfplan.json
``` 
</details></br>


Terraform plan could also be uploaded as an artifact in a separate job.

<details><summary>Terraform plan as artifact</summary>

``` yaml
      - name: Download tfplan
        uses: actions/download-artifact@v4
        with:
          name: tfplan
```
</details>

#### 2. Cloudability Credentials 

The workflow steps require a Frontdoor token to authenticate Cloudability Governance APIs.
`Get Frontdoor token` step in the template retrieves and sets a short-lived token, using Frontdoor API Key and Secret. 

The inputs for this step can be set as repository level variables and secrets. 
 - FD_URL : Frontdoor instance to retrieve token from , eg https://frontdoor.apptio.com
 - FD_KEY : Key for the Frontdoor user
 - FD_SECRET : Secret for the Frontdoor user

>**Note**: Frontdoor has a standard role `Cloudability Governance Automation User`. Key/Secret pair of an account with this role will have all the requisite permissions required for the workflow steps.

<details><summary><code>Get Frontdoor token</code></summary>

``` yaml
      - name: Get Frontdoor token
        uses: ibm/ibm-cloudability-governance/actions/frontdoor/login@v0.1.0
        with:
          fd-url: ${{ vars.FD_URL }}
          fd-public-key: ${{ secrets.FD_KEY }}
          fd-secret-key: ${{ secrets.FD_SECRET }}
```
</details>

#### 3. Metadata 

Metadata associated with a pull-request and Cloudability Governance is required to capture Governance configuration for customers organization. 

`Get GitHub PR metadata` step in the template calls the Github API to fetch PR related metadata 

<details><summary><code>Get Github PR metadata</code></summary>

``` yaml
      - name: Get GitHub PR metadata
        uses: ibm/ibm-cloudability-governance/actions/github-info@v0.1.0
        with:
          github-token: ${{ secrets.GITHUB_TOKEN }}
          pr-number: ${{ github.event.pull_request.number }}

```
</details></br>


`Cloudability Governance Metadata Retrieval` step in the template uses Cloudability API to fetch Governance configuration (project, deployment, pull request, github app installations) from Cloudability 


<details><summary><code>Cloudability Governance Metadata Retrieval</code></summary>

``` yaml
      - name: Run Cloudability Governance Metadata Retrieval
        uses: ibm/ibm-cloudability-governance/actions/metadata@v0.1.0
        with:
          cloudability-host: ${{ vars.CLOUDABILITY_HOST }}
          fd-env-id: ${{ secrets.FD_ENV_ID }}

```
</details></br>


This step requires the Frontdoor Environment Id for customers Cloudability organization and the Cloudability url host. They can be set as Github repository secrets or variables.

- FD_ENV_ID (Frontdoor Environment Id) 
- CLOUDABILITY_HOST (example: https://api.cloudability.com)

#### 4. Governance 

Governance consists of 3 components - `Cost Estimation` , `Policy Evaluation` and `Recommendations`.

We provide 3 separate action templates for each of these steps and they can be chosen as needed. 

>**Note**: `Frontdoor Token`,`Github Metadata` and `Cloudability Governance Metadata` are required for running any governance action. 

##### Cloud Provider Configuration

For running Governance actions, a `provider-accounts` input is needed. This is a map of [terraform provider key](https://developer.hashicorp.com/terraform/language/providers/configuration#provider-configuration-1) to a cloud vendor account Id. This is needed to fetch the pricing information from the correct cloud vendor account. 

The provider key can either be a wildcard `*`, indicating that this account is the default for any provider keys in the terraform plan, or it can be the exact provider config key as represented in the `configuration.provider_config` map in the terraform plan json. 

>For example, if a provider with local name `aws_usw2` is defined in a module called “database” and the root terraform module is calling the `database` module, the provider key will be `module.database:aws_usw2`

Here is an example setup where a default account is used. 

<details><summary><code>Governance actions for a deployment to a single cloud vendor account (using * as key in provider-accounts map)</code></summary>

``` yaml
      - name: Run Cloudability Cost Estimation
        uses: ibm/ibm-cloudability-governance/actions/cost-estimation@v0.1.0
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
        uses: ibm/ibm-cloudability-governance/actions/policy-evaluation@v0.1.0
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
        uses: ibm/ibm-cloudability-governance/actions/recommendation@v0.1.0
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

Alternatively, this is the setup for a scenario with a specific account alias.

<details><summary><code>Governance actions for a deployment to multiple cloud vendor accounts (using fully qualified key name in provider-accounts map)</code></summary>

``` yaml
      - name: Run Cloudability Cost Estimation
        uses: ibm/ibm-cloudability-governance/actions/cost-estimation@v0.1.0
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
              },
              "*": {
                "account_id": "${{ secrets.SECOND_AWS_ACCOUNT_ID }}", 
                "vendor": "aws"
              }
            }
          tf-plan: "tfplan.json"
          resource-usage: "usage.json"
```
</details>

##### Usage Information

Governance actions accept an additional usage file in json (usage.json) mapping expected resource usage to their resource identifiers.

If using YAML file, you can use [js-yaml](https://github.com/nodeca/js-yaml) and incorporate it within the workflow.

<details><summary><code>Adding usage input </code></summary>

``` yaml
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

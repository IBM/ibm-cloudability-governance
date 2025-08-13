## Structure
The `terragrunt` folder contains terragrunt files for multiple components. Each subfolder is a separate component and has its own usage input file. 

```
    /terragrunt
    | ----- /component-A
    |           | ----- terragrunt.hcl
    |           | ----- main.tf
    |           | ----- usage.json
    |
    | ----- /component-B
                | ----- terragrunt.hcl
                | ----- main.tf
                | ----- usage.json

```

## Handling terragrunt run-all output
Suppose that we need to use the `terragrunt run-all plan` command below to generate the plan file for all components at once, we will have a file containing multiple terraform plan. 
```
      - name: Run terragrunt plan
        run: |
          cd terragrunt
          terragrunt run-all plan \    
          --terragrunt-non-interactive \
          --terragrunt-parallelism 5 \
          --terragrunt-strict-include \
          --terragrunt-include-dir component-A \
          --terragrunt-include-dir component-B \
          -out tgplan.log
```
In Cloudability Governance, we treat each terraform plan as a separate deployment, so we're going to use matrix strategy in our action workflow to split the terragrunt run-all outcome into individual plans and invoke Cloudability Governance workflows for each plan. This is achieved by running `terragrunt run-all show` command and include only one component directory at a time.
```
      # only include one component dir to get the plan json for a single component
      - name: Convert plan output into json format each component
        run: |
          cd terragrunt
          terragrunt run-all show \    
          --terragrunt-non-interactive \
          --terragrunt-parallelism 5 \
          --terragrunt-strict-include \
          --terragrunt-include-dir ${{ matrix.components }} \
          --json tgplan.log > ${{ matrix.components }}/tfplan.json
```

## Using GitHub Artifact
The example utilizes GitHub Artifact to reuse the same run-all output in all matrix jobs so that we don't need to run the `terragrunt run-all plan` command multiple times. It's completely optional.
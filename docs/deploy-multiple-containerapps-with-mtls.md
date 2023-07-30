## Setup

- Set environment variables for the demo.

    ```sh
    RESOURCE_GROUP="trialcontainerapps"
    LOCATION="eastus2"
    ```

- Create resource group for the container-apps demo.

    ```sh
    az group create \
        --name ${RESOURCE_GROUP} \
        --location "${LOCATION}"
    ```

## Deploy Voting Microservices Application as ContainerApps

- Review the templates for the definition of a microservices application deployed as multiple container apps within the same container environment. It consists of the following:
    - Container App for Voting UI accessible externally on port `443`
    - Container App for Voting backend accessible internally on `tcp` port `6379`
    - Container App Environment for hosting the Container Apps and connected to Log Analytics workspace.
    - Communication between the Container Apps encrypted by mutual TLS.

   
- Deploy Voting Application using the `bicep` template.

```sh
az deployment group create --resource-group ${RESOURCE_GROUP} --template-file templates\main.bicep 
```

-  Deploy Voting Application using the `ARM` template.

> Note the FQDN for Voting Application UI in command output.

```sh
az deployment group create --resource-group ${RESOURCE_GROUP} --template-file templates\azure.deploy.json --parameters templates\azure.deploy.params.json 
```


- Open the ingress endpoint on a browser for `vote-app` to launch. 

    > **Note**: Azure Container Apps implements TLS by default for external ingress endpoint. Custom domains are not supported yet.

## Troubleshooting

- View logs for `vote-app` Containerapp using AZ CLI.

```sh
az monitor log-analytics query \
    --workspace $LOG_ANALYTICS_WORKSPACE_ID \
    --analytics-query "ContainerAppConsoleLogs_CL | where ContainerAppName_s == 'vote-app' and TimeGenerated > ago(30m) | project ContainerAppName_s, Log_s, TimeGenerated | take 100 | order by TimeGenerated desc" \
    --out table
```

## Clean-up

- Delete the container-apps resources to avoid incurring cost.

    ```sh
    az group delete --name $RESOURCE_GROUP
    ```

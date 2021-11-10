## Setup

- Set environment variables for the demo.

    ```sh
    RESOURCE_GROUP="saty-containerapps"
    LOCATION="canadacentral"
    LOG_ANALYTICS_WORKSPACE="saty-containerapps-logs"
    CONTAINERAPPS_ENVIRONMENT="saty-containerapps-env"
    ```

- Create resource group for the container-apps demo.

    ```sh
    az group create \
        --name $RESOURCE_GROUP \
        --location "$LOCATION"
    ```

- Create a new Log Analytics workspace with the following command

    > Azure Log Analytics is used to monitor your container app required when creating a Container Apps Environment.

    ```sh
    az monitor log-analytics workspace create \
        --resource-group $RESOURCE_GROUP \
        --workspace-name $LOG_ANALYTICS_WORKSPACE
    ```

- Retrieve the Log Analytics workspace id and key

    ```sh
    LOG_ANALYTICS_WORKSPACE_ID=`az monitor log-analytics workspace show --query customerId -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE --out tsv`

    LOG_ANALYTICS_WORKSPACE_KEY=`az monitor log-analytics workspace get-shared-keys --query primarySharedKey -g $RESOURCE_GROUP -n $LOG_ANALYTICS_WORKSPACE --out tsv`
    ```

## Create a Container Apps Environment

An environment in `Azure Container Apps` creates a secure boundary around a group of container apps. Container Apps deployed to the same environment are deployed in the same virtual network and write logs to the same Log Analytics workspace.

- Create a new environment with the following command.

    ```sh
    az containerapp env create \
        --name $CONTAINERAPPS_ENVIRONMENT \
        --resource-group $RESOURCE_GROUP \
        --logs-workspace-id $LOG_ANALYTICS_WORKSPACE_ID \
        --logs-workspace-key $LOG_ANALYTICS_WORKSPACE_KEY \
        --location "$LOCATION"
    ```


## Deploy a multi-container Voting Application as ContainerApp

- Review the `manifests/vote.containerapp.yaml` for the definition of a multi-container application. It consists of the following:
    - Main container `vote` listening on `http` port `80` 
    - Sidecar container `redis` listening on `tcp` port `6379`
    - Ingress for external enabled on target port `80`

    ```yaml
    cat manifests/vote.containerapp.yaml

    type: Microsoft.Web/containerApps
    template:
    containers:
    - name: redis
        image: mcr.microsoft.com/oss/bitnami/redis:6.0.8
        env:
        - name: TCP_PORT
          value: 6379
        - name: ALLOW_EMPTY_PASSWORD
          value: 'yes'
    - name: vote
        image: mcr.microsoft.com/azuredocs/azure-vote-front:v1
        env:
        - name: HTTP_PORT
          value: 80
        - name: REDIS
          value: localhost
    scale:
        maxReplicas: 1
        minReplicas: 1
    kubeEnvironmentId: /subscriptions/[SUBSCRIPTION_ID]/resourceGroups/[CONTAINER_APP_NAME]/providers/Microsoft.Web/kubeEnvironments/[CONTAINER_APP_ENV]
    configuration:
    activeRevisionsMode: Multiple
    ingress:
        external: true
        targetPort: 80
    ```

- Create a Containerapp for `vote-app` microservice using the `yaml` manifest.

    ```sh
    az containerapp create \
        --name vote-app \
        --resource-group $RESOURCE_GROUP \
        --yaml manifests/vote.containerapp.yaml
    ```

- Get the external ingress endpoint of `helloworld` Containerapp.

    ```sh
    az containerapp show \
        --name vote-app \
        --resource-group $RESOURCE_GROUP \
        --query configuration.ingress.fqdn
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

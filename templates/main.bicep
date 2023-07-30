@description('Specifies the name of the container app.')
param containerAppName string = 'votingapp'

@description('Specifies the name of the container app environment.')
param containerAppEnvName string = 'votingapp-env'

@description('Specifies the name of the log analytics workspace.')
param containerAppLogAnalyticsName string = 'votingapp-log'

@description('Specifies the location for all resources.')
@allowed([
  'eastus2'
  'centralus'
])
param location string = 'eastus2'

@description('Specifies the docker container image to deploy.')
param frontendContainerImage string = 'mcr.microsoft.com/azuredocs/azure-vote-front:v1'

@description('Specifies the docker container image to deploy for the Redis backend.')
param backendContainerImage string = 'mcr.microsoft.com/oss/bitnami/redis:6.0.8'

@description('Minimum number of replicas that will be deployed')
@minValue(0)
@maxValue(25)
param minReplica int = 1

@description('Maximum number of replicas that will be deployed')
@minValue(0)
@maxValue(25)
param maxReplica int = 3

resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2021-06-01' = {
  name: containerAppLogAnalyticsName
  location: location
  properties: {
    sku: {
      name: 'PerGB2018'
    }
  }
}

resource containerAppEnv 'Microsoft.App/managedEnvironments@2023-04-01-preview' = {
  name: containerAppEnvName
  location: location
  properties: {
    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
    peerAuthentication: {
      mtls: {
        enabled: true
      }
    }
  }
}

resource containerAppFrontend 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: '${containerAppName}-frontend'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: true
        targetPort: 80
        allowInsecure: false
        traffic: [
          {
            latestRevision: true
            weight: 100
          }
        ]
      }
    }
    template: {
      revisionSuffix: 'v3'
      containers: [
        {
          name: '${containerAppName}-frontend'
          image: frontendContainerImage
          env: [
            {
              name: 'REDIS'
              value: 'votingapp-backend'
              // value: 'localhost'
            }
          ]
          resources: {
            cpu: json('.25')
            memory: '.5Gi'
          }
        }
        {
          name: 'redis'
          image: backendContainerImage
          env: [
            {
              name: 'ALLOW_EMPTY_PASSWORD'
              value: 'yes'
            }
          ]
          resources: {
            cpu: json('.25')
            memory: '.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: minReplica
        maxReplicas: maxReplica
        rules: [
          {
            name: 'http-requests'
            http: {
              metadata: {
                concurrentRequests: '10'
              }
            }
          }
        ]
      }
    }
  }
}

resource containerAppBackend 'Microsoft.App/containerApps@2023-04-01-preview' = {
  name: '${containerAppName}-backend'
  location: location
  properties: {
    managedEnvironmentId: containerAppEnv.id
    configuration: {
      ingress: {
        external: false
        targetPort: 6379
        exposedPort: 6379
        transport: 'tcp'
      }
    }
    template: {
      revisionSuffix: 'v1'
      containers: [
        {
          name: '${containerAppName}-backend'
          image: backendContainerImage
          env: [
            {
              name: 'ALLOW_EMPTY_PASSWORD'
              value: 'yes'
            }
          ]
          resources: {
            cpu: json('.25')
            memory: '.5Gi'
          }
        }
      ]
      scale: {
        minReplicas: minReplica
        maxReplicas: maxReplica
      }
    }
  }
}

output containerAppFQDN string = containerAppFrontend.properties.configuration.ingress.fqdn

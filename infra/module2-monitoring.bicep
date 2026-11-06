// Module 2 - Data Collection Rule (DCR) + association with the scale set
// Scope: resource group
targetScope = 'resourceGroup'

param location string = resourceGroup().location
param vmssName string
param workspaceName string
param tags object = {
  project: 'azure-ha-ops-lab'
  env: 'workshop'
}

resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' existing = {
  name: workspaceName
}

resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-07-01' existing = {
  name: vmssName
}

// WHAT to collect, and WHERE to send it.
resource dcr 'Microsoft.Insights/dataCollectionRules@2023-03-11' = {
  name: 'dcr-halab-linux'
  location: location
  kind: 'Linux'
  tags: tags
  properties: {
    dataSources: {
      // -> Perf table
      performanceCounters: [
        {
          name: 'perfCounters'
          streams: [ 'Microsoft-Perf' ]
          samplingFrequencyInSeconds: 30
          counterSpecifiers: [
            'Processor(*)\\% Processor Time'
            'Memory(*)\\% Used Memory'
            'Logical Disk(*)\\% Used Space'
            'Network(*)\\Total Bytes'
          ]
        }
      ]
      // -> Syslog table
      syslog: [
        {
          name: 'syslogBase'
          streams: [ 'Microsoft-Syslog' ]
          facilityNames: [ 'auth', 'authpriv', 'daemon', 'kern', 'syslog' ]
          logLevels: [ 'Info', 'Notice', 'Warning', 'Error', 'Critical', 'Alert', 'Emergency' ]
        }
      ]
    }
    destinations: {
      logAnalytics: [
        {
          name: 'law'
          workspaceResourceId: workspace.id
        }
      ]
    }
    dataFlows: [
      {
        streams: [ 'Microsoft-Perf', 'Microsoft-Syslog' ]
        destinations: [ 'law' ]
      }
    ]
  }
}

// WHICH resources the rule applies to (all current and future instances of the scale set).
resource association 'Microsoft.Insights/dataCollectionRuleAssociations@2023-03-11' = {
  name: 'dcra-halab-vmss'
  scope: vmss
  properties: {
    dataCollectionRuleId: dcr.id
  }
}

output dcrName string = dcr.name

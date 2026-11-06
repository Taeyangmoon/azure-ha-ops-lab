// Module 0 - VNet + Standard Load Balancer + VM Scale Set (2 instances) + Log Analytics workspace
// Scope: resource group
targetScope = 'resourceGroup'

@description('Azure region. / 배포 리전')
param location string = resourceGroup().location

@description('Name prefix for resources. / 리소스 이름 접두사')
@minLength(2)
@maxLength(8)
param prefix string = 'halab'

@description('VM size. Use a size that your subscription has quota for. / VM 크기 (구독 할당량 확인)')
param vmSize string = 'Standard_B2s_v2'

@description('Initial instance count. / 초기 인스턴스 수')
@minValue(2)
@maxValue(4)
param instanceCount int = 2

@description('Spread instances across Availability Zones 1-3. Set false for regions without zones. / 가용성 영역 사용 여부')
param useAvailabilityZones bool = true

@description('Admin user name. (SSH is not exposed; you only need it for the VM profile.) / 관리자 계정')
param adminUsername string = 'azureuser'

@description('SSH public key for the admin user. / SSH 공개 키')
param sshPublicKey string

@description('Tags applied to every resource (used in Module 4 cost analysis). / 모든 리소스에 적용되는 태그 (모듈 4 비용 분석에 사용)')
param tags object = {
  project: 'azure-ha-ops-lab'
  env: 'workshop'
}

var suffix = uniqueString(resourceGroup().id)
var vnetName = '${prefix}-vnet'
var subnetName = 'web'
var nsgName = '${prefix}-web-nsg'
var pipName = '${prefix}-lb-pip'
var lbName = '${prefix}-lb'
var vmssName = '${prefix}-vmss'
var workspaceName = '${prefix}-law-${suffix}'
var zones = useAvailabilityZones ? [ '1', '2', '3' ] : []

// ---------------------------------------------------------------- Monitoring
resource workspace 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: workspaceName
  location: location
  tags: tags
  properties: {
    sku: { name: 'PerGB2018' }
    retentionInDays: 30
  }
}

// ---------------------------------------------------------------- Network
resource nsg 'Microsoft.Network/networkSecurityGroups@2024-05-01' = {
  name: nsgName
  location: location
  tags: tags
  properties: {
    securityRules: [
      {
        name: 'allow-http-inbound'
        properties: {
          priority: 100
          direction: 'Inbound'
          access: 'Allow'
          protocol: 'Tcp'
          sourceAddressPrefix: 'Internet'
          sourcePortRange: '*'
          destinationAddressPrefix: '*'
          destinationPortRange: '80'
        }
      }
    ]
  }
}

resource vnet 'Microsoft.Network/virtualNetworks@2024-05-01' = {
  name: vnetName
  location: location
  tags: tags
  properties: {
    addressSpace: { addressPrefixes: [ '10.0.0.0/16' ] }
    subnets: [
      {
        name: subnetName
        properties: {
          addressPrefix: '10.0.1.0/24'
          networkSecurityGroup: { id: nsg.id }
        }
      }
    ]
  }
}

resource pip 'Microsoft.Network/publicIPAddresses@2024-05-01' = {
  name: pipName
  location: location
  tags: tags
  sku: { name: 'Standard' }
  zones: zones
  properties: {
    publicIPAllocationMethod: 'Static'
    dnsSettings: { domainNameLabel: '${prefix}-${suffix}' }
  }
}

resource lb 'Microsoft.Network/loadBalancers@2024-05-01' = {
  name: lbName
  location: location
  tags: tags
  sku: { name: 'Standard' }
  properties: {
    frontendIPConfigurations: [
      {
        name: 'frontend'
        properties: { publicIPAddress: { id: pip.id } }
      }
    ]
    backendAddressPools: [ { name: 'web-pool' } ]
    probes: [
      {
        name: 'http-probe'
        properties: {
          protocol: 'Http'
          port: 80
          requestPath: '/'
          intervalInSeconds: 5
          numberOfProbes: 2
        }
      }
    ]
    loadBalancingRules: [
      {
        name: 'http-rule'
        properties: {
          protocol: 'Tcp'
          frontendPort: 80
          backendPort: 80
          idleTimeoutInMinutes: 4
          loadDistribution: 'Default'
          // Keep default outbound SNAT so instances can reach the internet (apt install) without a public IP.
          disableOutboundSnat: false
          frontendIPConfiguration: { id: resourceId('Microsoft.Network/loadBalancers/frontendIPConfigurations', lbName, 'frontend') }
          backendAddressPool: { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'web-pool') }
          probe: { id: resourceId('Microsoft.Network/loadBalancers/probes', lbName, 'http-probe') }
        }
      }
    ]
  }
}

// ---------------------------------------------------------------- Compute
resource vmss 'Microsoft.Compute/virtualMachineScaleSets@2024-07-01' = {
  name: vmssName
  location: location
  tags: tags
  zones: zones
  // System-assigned identity is required by Azure Monitor Agent (Module 2).
  identity: { type: 'SystemAssigned' }
  sku: {
    name: vmSize
    tier: 'Standard'
    capacity: instanceCount
  }
  properties: {
    overprovision: false
    singlePlacementGroup: false
    platformFaultDomainCount: 1
    // Automatic: model changes (e.g. the monitoring agent in Module 2) roll out to instances automatically.
    upgradePolicy: { mode: 'Automatic' }
    virtualMachineProfile: {
      storageProfile: {
        imageReference: {
          publisher: 'Canonical'
          offer: '0001-com-ubuntu-server-jammy'
          sku: '22_04-lts-gen2'
          version: 'latest'
        }
        osDisk: {
          createOption: 'FromImage'
          caching: 'ReadWrite'
          managedDisk: { storageAccountType: 'StandardSSD_LRS' }
        }
      }
      osProfile: {
        computerNamePrefix: 'web'
        adminUsername: adminUsername
        customData: loadFileAsBase64('cloud-init.yaml')
        linuxConfiguration: {
          disablePasswordAuthentication: true
          ssh: {
            publicKeys: [
              {
                path: '/home/${adminUsername}/.ssh/authorized_keys'
                keyData: sshPublicKey
              }
            ]
          }
        }
      }
      networkProfile: {
        networkInterfaceConfigurations: [
          {
            name: 'nic'
            properties: {
              primary: true
              ipConfigurations: [
                {
                  name: 'ipconfig'
                  properties: {
                    subnet: { id: '${vnet.id}/subnets/${subnetName}' }
                    loadBalancerBackendAddressPools: [
                      { id: resourceId('Microsoft.Network/loadBalancers/backendAddressPools', lbName, 'web-pool') }
                    ]
                  }
                }
              ]
            }
          }
        ]
      }
    }
  }
  dependsOn: [ lb ]
}

output vmssName string = vmss.name
output lbPublicIp string = pip.properties.ipAddress
output lbFqdn string = pip.properties.dnsSettings.fqdn
output workspaceName string = workspace.name
output workspaceId string = workspace.id
output workspaceCustomerId string = workspace.properties.customerId

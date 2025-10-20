@description('The base URI where artifacts required by this template are located including a trailing /')
param artifactsLocation string = 'https://raw.githubusercontent.com/crgarcia12/azure-migrate-env/main/'

@description('Location for all resources.')
param location string = 'swedencentral'

@description('VM Password')
@secure()
param vmPassword string

@description('Resource name prefix')
param prefix string

// Variables (locals from Terraform)
var vnetName = '${prefix}-vnet'
var addressSpaces = ['172.100.0.0/17']
var vmName = '${prefix}-vm'

var subnets = [
  { name: 'nat', addressPrefix: '172.100.0.0/24', nsgName: 'nat-nsg', privateIp: '172.100.0.4' }
  { name: 'hypervlan', addressPrefix: '172.100.1.0/24', nsgName: 'hyperv-nsg', privateIp: '172.100.1.4' }
  { name: 'ghosted', addressPrefix: '172.100.2.0/24', nsgName: 'ghosted-nsg', privateIp: '' }
  { name: 'azurevms', addressPrefix: '172.100.3.0/24', nsgName: 'azurevms-nsg', privateIp: '' }
]

var ghostedSubnetAddressPrefix = subnets[2].addressPrefix

var nsgRules = {
  'nat-nsg': [
    {
      name: 'RDP'
      priority: 100
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3389'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '172.100.0.4'
    }
  ]
  'hyperv-nsg': [
    {
      name: 'RDP'
      priority: 100
      direction: 'Inbound'
      access: 'Allow'
      protocol: 'Tcp'
      sourcePortRange: '*'
      destinationPortRange: '3389'
      sourceAddressPrefix: '*'
      destinationAddressPrefix: '172.100.1.4'
    }
  ]
  'ghosted-nsg': []
  'azurevms-nsg': []
}

var dscInstallWindowsFeaturesUri = '${artifactsLocation}scripts/dscinstallwindowsfeatures.zip'
var hvHostSetupScriptUri = '${artifactsLocation}scripts/hvhostsetup.ps1'

// Deploy Virtual Network
module virtualNetwork 'modules/virtual-network.bicep' = {
  name: 'deploy-vnet'
  params: {
    name: vnetName
    location: location
    addressSpaces: addressSpaces
    subnets: [for subnet in subnets: {
      name: subnet.name
      addressPrefix: subnet.addressPrefix
    }]
  }
}

// Deploy NSGs
module nsgs 'modules/network-security-group.bicep' = [for subnet in subnets: {
  name: 'deploy-nsg-${subnet.nsgName}'
  params: {
    name: '${vmName}-${subnet.nsgName}'
    location: location
    securityRules: nsgRules[subnet.nsgName]
  }
}]

// Deploy Public IP
module publicIp 'modules/public-ip.bicep' = {
  name: 'deploy-public-ip'
  params: {
    name: '${vmName}-ip'
    location: location
    allocationMethod: 'Static'
    sku: 'Standard'
  }
}

// Deploy Storage Account for diagnostics
module storageAccount 'modules/storage-account.bicep' = {
  name: 'deploy-storage'
  params: {
    name: replace('${prefix}-diag', '-', '')
    location: location
    skuName: 'Standard_LRS'
    kind: 'StorageV2'
  }
}

// Deploy Route Table
module routeTable 'modules/route-table.bicep' = {
  name: 'deploy-route-table'
  params: {
    name: 'udr-${vnetName}-azurevms'
    location: location
    routes: [
      {
        name: 'Nested-VMs'
        addressPrefix: ghostedSubnetAddressPrefix
        nextHopType: 'VirtualAppliance'
        nextHopIpAddress: '172.100.1.4' // Secondary NIC IP
      }
    ]
  }
}

// Associate NSGs with Subnets (and Route Table for azurevms)
@batchSize(1)
resource nsgAssociations 'Microsoft.Network/virtualNetworks/subnets@2023-11-01' = [for (subnet, i) in subnets: {
  name: '${vnetName}/${subnet.name}'
  properties: {
    addressPrefix: subnet.addressPrefix
    networkSecurityGroup: {
      id: nsgs[i].outputs.nsgId
    }
    routeTable: subnet.name == 'azurevms' ? {
      id: routeTable.outputs.routeTableId
    } : null
  }
  dependsOn: [
    virtualNetwork
    nsgs
  ]
}]

// Deploy Primary NIC
module nicPrimary 'modules/network-interface.bicep' = {
  name: 'deploy-nic-primary'
  params: {
    name: '${vmName}-nic-primary'
    location: location
    subnetId: virtualNetwork.outputs.subnets[0].id
    privateIpAllocationMethod: 'Static'
    privateIpAddress: '172.100.0.4'
    publicIpAddressId: publicIp.outputs.publicIpId
    enableAcceleratedNetworking: false
  }
  dependsOn: [
    nsgAssociations
  ]
}

// Deploy Secondary NIC
module nicSecondary 'modules/network-interface.bicep' = {
  name: 'deploy-nic-secondary'
  params: {
    name: '${vmName}-nic-secondary'
    location: location
    subnetId: virtualNetwork.outputs.subnets[1].id
    privateIpAllocationMethod: 'Static'
    privateIpAddress: '172.100.1.4'
    enableAcceleratedNetworking: true
  }
  dependsOn: [
    nsgAssociations
  ]
}

// Deploy Windows VM
module windowsVm 'modules/windows-vm.bicep' = {
  name: 'deploy-windows-vm'
  params: {
    name: vmName
    location: location
    vmSize: 'Standard_E16_v3'
    adminUsername: 'adminuser'
    adminPassword: vmPassword
    networkInterfaceIds: [
      nicPrimary.outputs.nicId
      nicSecondary.outputs.nicId
    ]
    osDiskName: '${vmName}-os'
    osDiskStorageAccountType: 'Standard_LRS'
    dataDisks: [
      {
        name: '${vmName}-disk1'
        createOption: 'Empty'
        diskSizeGB: 1024
        storageAccountType: 'Standard_LRS'
        caching: 'ReadOnly'
      }
    ]
    bootDiagnosticsStorageUri: storageAccount.outputs.primaryBlobEndpoint
    dscConfiguration: {
      wmfVersion: 'latest'
      configuration: {
        url: dscInstallWindowsFeaturesUri
        script: 'DSCInstallWindowsFeatures.ps1'
        function: 'InstallWindowsFeatures'
      }
    }
    customScriptExtension: {
      fileUris: [
        hvHostSetupScriptUri
      ]
      commandToExecute: 'powershell -ExecutionPolicy Unrestricted -File hvhostsetup.ps1 -NIC1IPAddress ${nicPrimary.outputs.privateIpAddress} -NIC2IPAddress ${nicSecondary.outputs.privateIpAddress} -GhostedSubnetPrefix ${ghostedSubnetAddressPrefix} -VirtualNetworkPrefix ${addressSpaces[0]}'
    }
  }
}

module azureMigrate 'modules/azure-migrate.bicep' = {
  name: 'deploy-azuire-migrate'
  params: {
    location: location  
    name: '${prefix}-azm'
  }
}

// Outputs
output vnetName string = virtualNetwork.outputs.vnetName
output vmName string = windowsVm.outputs.vmName
output publicIpAddress string = publicIp.outputs.publicIpAddress

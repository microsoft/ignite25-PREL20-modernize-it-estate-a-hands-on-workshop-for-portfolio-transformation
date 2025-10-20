// Default parameters (can be overridden during deployment)
@description('The name of the public IP address')
param name string = 'crgar-migr-vm-ip'

@description('The location for the public IP address')
param location string = 'swedencentral'

@description('The allocation method for the public IP')
@allowed([
  'Static'
  'Dynamic'
])
param allocationMethod string = 'Static'

@description('The SKU of the public IP')
@allowed([
  'Basic'
  'Standard'
])
param sku string = 'Standard'

@description('Tags to apply to the public IP')
param tags object = {}

resource publicIp 'Microsoft.Network/publicIPAddresses@2023-11-01' = {
  name: name
  location: location
  tags: tags
  sku: {
    name: sku
  }
  properties: {
    publicIPAllocationMethod: allocationMethod
  }
}

output publicIpName string = publicIp.name
output publicIpId string = publicIp.id
output publicIpAddress string = publicIp.properties.ipAddress

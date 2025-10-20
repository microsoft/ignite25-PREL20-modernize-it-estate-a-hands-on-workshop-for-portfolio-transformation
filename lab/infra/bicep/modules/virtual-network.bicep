// Default parameters (can be overridden during deployment)
@description('The name of the virtual network')
param name string = 'crgar-migr-vnet'

@description('The location for the virtual network')
param location string = 'swedencentral'

@description('The address spaces for the virtual network')
param addressSpaces array = [
  '172.100.0.0/17'
]

@description('The subnets to create')
param subnets array = [
  {
    name: 'nat'
    addressPrefix: '172.100.0.0/24'
  }
  {
    name: 'hypervlan'
    addressPrefix: '172.100.1.0/24'
  }
  {
    name: 'ghosted'
    addressPrefix: '172.100.2.0/24'
  }
  {
    name: 'azurevms'
    addressPrefix: '172.100.3.0/24'
  }
]

@description('Tags to apply to the virtual network')
param tags object = {}

resource vnet 'Microsoft.Network/virtualNetworks@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    addressSpace: {
      addressPrefixes: addressSpaces
    }
    subnets: [for subnet in subnets: {
      name: subnet.name
      properties: {
        addressPrefix: subnet.addressPrefix
      }
    }]
  }
}

output vnetName string = vnet.name
output vnetId string = vnet.id
output subnets array = [for (subnet, i) in subnets: {
  name: vnet.properties.subnets[i].name
  id: vnet.properties.subnets[i].id
  addressPrefix: vnet.properties.subnets[i].properties.addressPrefix
}]

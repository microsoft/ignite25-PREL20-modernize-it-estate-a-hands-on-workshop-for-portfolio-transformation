// Default parameters (can be overridden during deployment)
@description('The name of the route table')
param name string = 'udr-example-vnet-azurevms'

@description('The location for the route table')
param location string = 'swedencentral'

@description('Routes to create in the route table')
param routes array = [
  {
    name: 'Nested-VMs'
    addressPrefix: '172.100.2.0/24'
    nextHopType: 'VirtualAppliance'
    nextHopIpAddress: '172.100.1.4'
  }
]

@description('Tags to apply to the route table')
param tags object = {}

resource routeTable 'Microsoft.Network/routeTables@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    routes: [for route in routes: {
      name: route.name
      properties: {
        addressPrefix: route.addressPrefix
        nextHopType: route.nextHopType
        nextHopIpAddress: route.?nextHopIpAddress
      }
    }]
  }
}

output routeTableName string = routeTable.name
output routeTableId string = routeTable.id

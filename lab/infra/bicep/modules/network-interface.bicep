// Default parameters (can be overridden during deployment)
@description('The name of the network interface')
param name string = 'example-nic'

@description('The location for the network interface')
param location string = 'swedencentral'

@description('The subnet ID to attach the NIC to')
param subnetId string

@description('The private IP address allocation method')
@allowed([
  'Static'
  'Dynamic'
])
param privateIpAllocationMethod string = 'Static'

@description('The private IP address (required if allocation method is Static)')
param privateIpAddress string = '172.100.0.4'

@description('The public IP address ID (optional)')
param publicIpAddressId string = ''

@description('Enable accelerated networking')
param enableAcceleratedNetworking bool = false

@description('Network security group ID (optional)')
param networkSecurityGroupId string = ''

@description('Tags to apply to the network interface')
param tags object = {}

resource nic 'Microsoft.Network/networkInterfaces@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    ipConfigurations: [
      {
        name: '${name}-ipconfig'
        properties: {
          subnet: {
            id: subnetId
          }
          privateIPAllocationMethod: privateIpAllocationMethod
          privateIPAddress: privateIpAllocationMethod == 'Static' ? privateIpAddress : null
          publicIPAddress: !empty(publicIpAddressId) ? {
            id: publicIpAddressId
          } : null
        }
      }
    ]
    enableAcceleratedNetworking: enableAcceleratedNetworking
    networkSecurityGroup: !empty(networkSecurityGroupId) ? {
      id: networkSecurityGroupId
    } : null
  }
}

output nicName string = nic.name
output nicId string = nic.id
output privateIpAddress string = nic.properties.ipConfigurations[0].properties.privateIPAddress

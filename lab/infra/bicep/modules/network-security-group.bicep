// Default parameters (can be overridden during deployment)
@description('The name of the network security group')
param name string = 'example-nsg'

@description('The location for the network security group')
param location string = 'swedencentral'

@description('The security rules to create')
param securityRules array = [
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

@description('Tags to apply to the network security group')
param tags object = {}

resource nsg 'Microsoft.Network/networkSecurityGroups@2023-11-01' = {
  name: name
  location: location
  tags: tags
  properties: {
    securityRules: [for rule in securityRules: {
      name: rule.name
      properties: {
        priority: rule.priority
        direction: rule.direction
        access: rule.access
        protocol: rule.protocol
        sourcePortRange: rule.sourcePortRange
        destinationPortRange: rule.destinationPortRange
        sourceAddressPrefix: rule.sourceAddressPrefix
        destinationAddressPrefix: rule.destinationAddressPrefix
      }
    }]
  }
}

output nsgName string = nsg.name
output nsgId string = nsg.id

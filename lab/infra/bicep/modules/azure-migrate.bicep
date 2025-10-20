@description('Resource name prefix')
param name string

@description('The location for the Azure Migrate project')
param location string = 'westus2'

@description('Tags to apply to the Azure Migrate project')
param tags object = {}

// Create Azure Migrate Project
resource migrateProject 'Microsoft.Migrate/MigrateProjects@2020-06-01-preview' = {
  name: name
  location: location
  tags: union(tags, {
    'Migrate Project': name
  })
  properties: {}
}

// Server Assessment Solution
resource serverAssessmentSolution 'Microsoft.Migrate/MigrateProjects/Solutions@2020-06-01-preview' = {
  parent: migrateProject
  name: 'Servers-Assessment-ServerAssessment'
  properties: {
    tool: 'ServerAssessment'
    purpose: 'Assessment'
    goal: 'Servers'
  }
}

// Server Discovery Solution
resource serverDiscoverySolution 'Microsoft.Migrate/MigrateProjects/Solutions@2020-06-01-preview' = {
  parent: migrateProject
  name: 'Servers-Discovery-ServerDiscovery'
  properties: {
    tool: 'ServerDiscovery'
    purpose: 'Discovery'
    goal: 'Servers'
  }
  dependsOn: [
    serverAssessmentSolution
  ]
}

// Server Migration Solution
resource serverMigrationSolution 'Microsoft.Migrate/MigrateProjects/Solutions@2020-06-01-preview' = {
  parent: migrateProject
  name: 'Servers-Migration-ServerMigration'
  properties: {
    tool: 'ServerMigration'
    purpose: 'Migration'
    goal: 'Servers'
  }
  dependsOn: [
    serverDiscoverySolution
  ]
}

// Server Migration Data Replication Solution
resource serverMigrationDataReplicationSolution 'Microsoft.Migrate/MigrateProjects/Solutions@2020-06-01-preview' = {
  parent: migrateProject
  name: 'Servers-Migration-ServerMigration_DataReplication'
  properties: {
    tool: 'ServerMigration_DataReplication'
    purpose: 'Migration'
    goal: 'Servers'
  }
  dependsOn: [
    serverMigrationSolution
  ]
}

output migrateProjectName string = migrateProject.name
output migrateProjectId string = migrateProject.id
output location string = migrateProject.location

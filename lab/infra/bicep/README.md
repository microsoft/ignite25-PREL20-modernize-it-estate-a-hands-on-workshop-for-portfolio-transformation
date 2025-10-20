# Azure Bicep Deployment

This directory contains the Bicep infrastructure-as-code templates for deploying the Azure Migrate environment, converted from the original Terraform configuration.

## Structure

```
infra/bicep/
├── main.bicep                          # Main orchestration file
├── main.bicepparam                     # Parameters for main deployment
├── modules/                            # Reusable Bicep modules
│   ├── resource-group.bicep
│   ├── resource-group.bicepparam
│   ├── virtual-network.bicep
│   ├── virtual-network.bicepparam
│   ├── network-security-group.bicep
│   ├── network-security-group.bicepparam
│   ├── public-ip.bicep
│   ├── public-ip.bicepparam
│   ├── network-interface.bicep
│   ├── network-interface.bicepparam
│   ├── route-table.bicep
│   ├── route-table.bicepparam
│   ├── storage-account.bicep
│   ├── storage-account.bicepparam
│   ├── windows-vm.bicep
│   └── windows-vm.bicepparam
```

## Modules

Each module is a self-contained, reusable component with its own parameter file:

- **resource-group**: Creates an Azure Resource Group (subscription-scoped)
- **virtual-network**: Creates a VNet with multiple subnets
- **network-security-group**: Creates NSGs with configurable security rules
- **public-ip**: Creates a public IP address
- **network-interface**: Creates a network interface with optional public IP and NSG
- **route-table**: Creates a route table with custom routes
- **storage-account**: Creates a storage account for diagnostics
- **windows-vm**: Creates a Windows VM with data disks and extensions (DSC and Custom Script)

## Deployment

### Prerequisites

- Azure CLI installed
- Bicep CLI installed (comes with Azure CLI 2.20.0+)
- Appropriate Azure subscription access
- A password for the VM

### Deploy the Resource Group

First, create the resource group at subscription scope:

```powershell
# Login to Azure
az login

# Set the subscription
az account set --subscription "96c2852b-cf88-4a55-9ceb-d632d25b83a4"

# Create resource group
az deployment sub create `
  --location swedencentral `
  --template-file modules/resource-group.bicep `
  --parameters modules/resource-group.bicepparam
```

### Deploy the Infrastructure

Then, deploy the main infrastructure to the resource group:

```powershell
# Set your VM password
$vmPassword = Read-Host "Enter VM password" -AsSecureString
$vmPasswordText = [Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR($vmPassword))

# Deploy infrastructure
az deployment group create `
  --resource-group crgar-migr-rg `
  --template-file main.bicep `
  --parameters main.bicepparam `
  --parameters vmPassword=$vmPasswordText
```

### Deploy Using What-If

To preview changes before deployment:

```powershell
az deployment group what-if `
  --resource-group crgar-migr-rg `
  --template-file main.bicep `
  --parameters main.bicepparam `
  --parameters vmPassword=$vmPasswordText
```

## Parameters

Key parameters in `main.bicepparam`:

- **artifactsLocation**: Base URI for scripts and artifacts
- **location**: Azure region for deployment
- **vmPassword**: Secure password for the VM admin account
- **prefix**: Resource naming prefix

## Resources Deployed

The deployment creates:

1. **Virtual Network** with 4 subnets:
   - nat (172.100.0.0/24)
   - hypervlan (172.100.1.0/24)
   - ghosted (172.100.2.0/24)
   - azurevms (172.100.3.0/24)

2. **Network Security Groups** for each subnet with RDP rules

3. **Public IP** for external access

4. **Storage Account** for boot diagnostics

5. **2 Network Interfaces**:
   - Primary NIC with public IP
   - Secondary NIC with accelerated networking

6. **Route Table** to route traffic through the Hyper-V host

7. **Windows VM** (Standard_E16_v3) with:
   - Windows Server 2022 Datacenter
   - 1TB data disk
   - DSC extension for Windows features
   - Custom script extension for Hyper-V setup

## Outputs

The deployment outputs:

- `vnetName`: Name of the virtual network
- `vmName`: Name of the virtual machine
- `publicIpAddress`: Public IP address for remote access

## Customization

To customize the deployment, edit the parameter files or override parameters at deployment time:

```powershell
az deployment group create `
  --resource-group crgar-migr-rg `
  --template-file main.bicep `
  --parameters main.bicepparam `
  --parameters location=eastus `
  --parameters prefix=myapp `
  --parameters vmPassword=$vmPasswordText
```

## Comparison with Terraform

This Bicep deployment is functionally equivalent to the Terraform configuration in `infra/terraform/`:

- Modular structure with reusable components
- Same resources and configurations
- Uses native Azure Resource Manager API
- No state file management required (Azure is the state)
- Better integration with Azure tooling and portal

## Cleanup

To delete all resources:

```powershell
az group delete --name crgar-migr-rg --yes --no-wait
```

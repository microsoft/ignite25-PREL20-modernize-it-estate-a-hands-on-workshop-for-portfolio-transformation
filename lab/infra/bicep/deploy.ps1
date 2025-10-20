# Azure Bicep Deployment Script
# This script deploys the Azure Migrate environment using Bicep

param(
    [Parameter(Mandatory=$true)]
    [string]$SubscriptionId = "96c2852b-cf88-4a55-9ceb-d632d25b83a4",
    
    [Parameter(Mandatory=$true)]
    [SecureString]$VmPassword,
    
    [Parameter(Mandatory=$false)]
    [string]$Location = "swedencentral",
    
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName = "crgar-migr-rg",
    
    [Parameter(Mandatory=$false)]
    [switch]$WhatIf
)

# Set error action preference
$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Azure Bicep Deployment Script" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Azure CLI is installed
Write-Host "Checking Azure CLI installation..." -ForegroundColor Yellow
try {
    $azVersion = az version --output json | ConvertFrom-Json
    Write-Host "✓ Azure CLI version: $($azVersion.'azure-cli')" -ForegroundColor Green
} catch {
    Write-Error "Azure CLI is not installed. Please install it from https://docs.microsoft.com/cli/azure/install-azure-cli"
    exit 1
}

# Check if Bicep is installed
Write-Host "Checking Bicep installation..." -ForegroundColor Yellow
try {
    $bicepVersion = az bicep version
    Write-Host "✓ Bicep version: $bicepVersion" -ForegroundColor Green
} catch {
    Write-Host "Bicep is not installed. Installing..." -ForegroundColor Yellow
    az bicep install
    Write-Host "✓ Bicep installed successfully" -ForegroundColor Green
}

# Login to Azure
Write-Host "`nLogging in to Azure..." -ForegroundColor Yellow
$account = az account show --output json 2>$null | ConvertFrom-Json
if (-not $account) {
    Write-Host "Not logged in. Please login..." -ForegroundColor Yellow
    az login
    $account = az account show --output json | ConvertFrom-Json
}
Write-Host "✓ Logged in as: $($account.user.name)" -ForegroundColor Green

# Set subscription
Write-Host "`nSetting subscription..." -ForegroundColor Yellow
az account set --subscription $SubscriptionId
Write-Host "✓ Using subscription: $(az account show --query name -o tsv)" -ForegroundColor Green

# Convert secure string to plain text
$BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($VmPassword)
$vmPasswordText = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)

# Deploy Resource Group
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Step 1: Deploying Resource Group" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "Running What-If analysis for Resource Group..." -ForegroundColor Yellow
    az deployment sub what-if `
        --location $Location `
        --template-file "$PSScriptRoot\modules\resource-group.bicep" `
        --parameters "$PSScriptRoot\modules\resource-group.bicepparam"
} else {
    Write-Host "Creating Resource Group: $ResourceGroupName..." -ForegroundColor Yellow
    $rgDeployment = az deployment sub create `
        --location $Location `
        --template-file "$PSScriptRoot\modules\resource-group.bicep" `
        --parameters "$PSScriptRoot\modules\resource-group.bicepparam" `
        --output json | ConvertFrom-Json
    
    if ($rgDeployment.properties.provisioningState -eq "Succeeded") {
        Write-Host "✓ Resource Group deployed successfully" -ForegroundColor Green
    } else {
        Write-Error "Resource Group deployment failed"
        exit 1
    }
}

# Deploy Infrastructure
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Step 2: Deploying Infrastructure" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan

if ($WhatIf) {
    Write-Host "Running What-If analysis for Infrastructure..." -ForegroundColor Yellow
    az deployment group what-if `
        --resource-group $ResourceGroupName `
        --template-file "$PSScriptRoot\main.bicep" `
        --parameters "$PSScriptRoot\main.bicepparam" `
        --parameters vmPassword=$vmPasswordText
} else {
    Write-Host "Deploying infrastructure to Resource Group: $ResourceGroupName..." -ForegroundColor Yellow
    Write-Host "This may take 15-30 minutes..." -ForegroundColor Yellow
    
    $infraDeployment = az deployment group create `
        --resource-group $ResourceGroupName `
        --template-file "$PSScriptRoot\main.bicep" `
        --parameters "$PSScriptRoot\main.bicepparam" `
        --parameters vmPassword=$vmPasswordText `
        --output json | ConvertFrom-Json
    
    if ($infraDeployment.properties.provisioningState -eq "Succeeded") {
        Write-Host "`n✓ Infrastructure deployed successfully!" -ForegroundColor Green
        
        # Display outputs
        Write-Host "`n========================================" -ForegroundColor Cyan
        Write-Host "Deployment Outputs" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "VNet Name: $($infraDeployment.properties.outputs.vnetName.value)" -ForegroundColor White
        Write-Host "VM Name: $($infraDeployment.properties.outputs.vmName.value)" -ForegroundColor White
        Write-Host "Public IP: $($infraDeployment.properties.outputs.publicIpAddress.value)" -ForegroundColor White
        Write-Host "`n✓ You can now connect to the VM using RDP" -ForegroundColor Green
        Write-Host "  Username: adminuser" -ForegroundColor White
        Write-Host "  IP Address: $($infraDeployment.properties.outputs.publicIpAddress.value)" -ForegroundColor White
    } else {
        Write-Error "Infrastructure deployment failed"
        exit 1
    }
}

Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "Deployment Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Cyan

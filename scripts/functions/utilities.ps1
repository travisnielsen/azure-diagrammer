function Get-PaasMarkup {
    param (
        [Parameter(Mandatory=$true)] $PaasName,
        [Parameter(Mandatory=$true)] $DictData,
        [Parameter(Mandatory=$true)] $LocationId,
        [Parameter(Mandatory=$true)] $SubscriptionId
    )

    $paasMarkup = ""
    $subnetMarkupIds = ""
    $regionName = Get-RegionName $LocationId

    # create list of subnet markup Ids to draw connectivity via Service Endpoints
    $vnetData = $DictData["vnets"] | Where-Object { $_.Location -eq $LocationId -and $_.SubscriptionId -eq $SubscriptionId }
    if ($vnetData) { $subnetMarkupIds = Get-SubnetMarkupIds $vnetData }

    switch ($PaasName) {
        "sites" {
            $appServicePlans = $DictData["serverfarms"] | Where-Object { $_.Location -eq $regionName -and $_.SubscriptionId -eq $SubscriptionId }
            $appServices = $DictData["sites"] | Where-Object { $_.Location -eq $regionName -and $_.SubscriptionId -eq $SubscriptionId }
            if ($appServicePlans) { return Get-AppServiceMarkup $appServices $appServicePlans }
        }
        # "eventHubNamespaces" { $paasMarkup = Get-EventHubMarkup $DictData["eventHubNamespaces"] $DictData["eventHubClusters"] }
        # "serviceBusNamespaces" { $paasMarkup = Get-ServiceBusMarkup $DictData["serviceBusNamespaces"] }
        "cosmosDbAccounts" { 
            $cosmosData = $DictData["cosmosDbAccounts"] | Where-Object { $_.Location -eq $regionName -and $_.SubscriptionId -eq $SubscriptionId }
            if ($cosmosData) { return Get-CosmosDbMarkup $cosmosData $subnetMarkupIds }
        }
        default { $paasMarkup }
    }

}

function Get-RegionName {
    param ( [Parameter(Mandatory=$true,Position=0)] $LocationId )

    switch ($LocationId) {
        "centralus" { "Central US" }
        "eastus" { "East US" }
        "eastus2" { 'East US 2' }
    }
}

function Get-SubnetMarkupIds {
    param ( [Parameter(Mandatory=$true,Position=0)] $VnetData )

    $subnetIds = New-Object -TypeName 'System.Collections.ArrayList'

    foreach ($vnet in $VnetData) {
        $subnets = $vnet.Properties.subnets

        foreach ($subnet in $subnets) {
            $subnetMarkupId = $subnet.name.Replace("-", "")
            $subnetIds.Add($subnetMarkupId)
        }
    }

    $subnetIds
}
# load subscription and tenant IDs
$contextInfo = Get-Content ./config.json | ConvertFrom-Json
$azContext = Get-AzContext
$arrSubscriptions = New-Object -TypeName 'System.Collections.ArrayList'

if ($null -eq $azContext) {
    Connect-AzAccount -Subscription $contextInfo.subscriptionId -Tenant $contextInfo.tenantId
    $arrSubscriptions.Add($contextInfo.subscriptionId)
} else {
    Set-AzContext -Subscription $contextInfo.subscriptionId
}

# get subscription vnet info and save
$vnets = Get-AzResource -ResourceType "Microsoft.Network/virtualNetworks" -ExpandProperties

$listVnets = New-Object -TypeName 'System.Collections.ArrayList'
foreach ($vnet in $vnets) {
    $listVnets.Add($vnet)
}

# add peered vnets from other subscriptions

$listRemoteVnetIds = New-Object -TypeName 'System.Collections.ArrayList'

foreach ($vnet in $vnets) {
    $peerings = $vnet.Properties.virtualNetworkPeerings
    if ($peerings.length -gt 0 ) {
        foreach ($peering in $peerings) {
            $remoteNetworkId = $peering.Properties.remoteVirtualNetwork.id

            if ($listRemoteVnetIds -notcontains $remoteNetworkId) {
                $listRemoteVnetIds.Add($remoteNetworkId)
            }
        }
    }
}

foreach ($vnetId in $arrRemoteVnetIds) {
    $remoteNetworkSubscriptionId = $vnetId.split("/")[2]
    $currentContext = Get-AzContext

    if ($remoteNetworkSubscriptionId -ne $currentContext.Subscription.Id ) {
        $newContext = Set-AzContext -Subscription $remoteNetworkSubscriptionId
    }

    $remoteVnet = Get-AzResource -ResourceId $vnetId -ExpandProperties
    $listVnets.Add($remoteVnet)
}


# $routeTables = Get-AzResource -ResourceType "Microsoft.Network/routeTables" -ExpandProperties

# $nsgs = Get-AzResource -ResourceType "Microsoft.Network/networkSecurityGroups" -ExpandProperties


ConvertTo-Json -InputObject $listVnets -Depth 7 | Out-File "vnets.json"
# ConvertTo-Json -InputObject $routeTables -Depth 7 | Out-File "routeTables.json"
# ConvertTo-Json -InputObject $nsgs -Depth 7 | Out-File "nsgs.json"
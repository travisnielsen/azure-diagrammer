# load subscription and tenant IDs
$contextInfo = Get-Content ./config.json | ConvertFrom-Json
$azContext = Get-AzContext
$listSubscriptions = New-Object -TypeName 'System.Collections.ArrayList'

if ($null -eq $azContext) {
    Connect-AzAccount -Subscription $contextInfo.subscriptionId -Tenant $contextInfo.tenantId
    $listSubscriptions.Add($contextInfo.subscriptionId)
} else {
    Set-AzContext -Subscription $contextInfo.subscriptionId
    $listSubscriptions.Add($contextInfo.subscriptionId)
}

# get subscription vnet info and save
$listVnets = New-Object -TypeName 'System.Collections.ArrayList'
$vnets = Get-AzResource -ResourceType "Microsoft.Network/virtualNetworks" -ExpandProperties
$vnets | ForEach-Object { $listVnets.Add($_) }

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

foreach ($vnetId in $listRemoteVnetIds) {
    $remoteNetworkSubscriptionId = $vnetId.split("/")[2]
    $currentContext = Get-AzContext

    if ($remoteNetworkSubscriptionId -ne $currentContext.Subscription.Id ) {
        Set-AzContext -Subscription $remoteNetworkSubscriptionId
        $listSubscriptions.Add($remoteNetworkSubscriptionId)
    }

    $remoteVnet = Get-AzResource -ResourceId $vnetId -ExpandProperties
    $listVnets.Add($remoteVnet)
}

$subscriptions = $listSubscriptions | Select-Object -Unique
$listRouteTables = New-Object -TypeName 'System.Collections.ArrayList'
$listNsgs = New-Object -TypeName 'System.Collections.ArrayList'
$listFirewalls = New-Object -TypeName 'System.Collections.ArrayList'
$listNatGateways = New-Object -TypeName 'System.Collections.ArrayList'
$listAppGateways = New-Object -TypeName 'System.Collections.ArrayList'
$listVnetGateways = New-Object -TypeName 'System.Collections.ArrayList'
$listExpressRouteGateways = New-Object -TypeName 'System.Collections.ArrayList'

foreach ($subscription in $subscriptions) {
    Set-AzContext -Subscription $subscription
    Get-AzResource -ResourceType "Microsoft.Network/routeTables" -ExpandProperties | ForEach-Object { $listRouteTables.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/networkSecurityGroups" -ExpandProperties | ForEach-Object { $listNsgs.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/azureFirewalls" -ExpandProperties | ForEach-Object { $listFirewalls.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/natGateways" -ExpandProperties | ForEach-Object { $listNatGateways.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/applicationGateways" -ExpandProperties | ForEach-Object { $listAppGateways.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/virtualNetworkGateways" -ExpandProperties | ForEach-Object { $listVnetGateways.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/expressRouteCircuits" -ExpandProperties | ForEach-Object { $listExpressRouteGateways.Add($_) }
}

ConvertTo-Json -InputObject $listVnets -Depth 7 | Out-File "vnets.json"
ConvertTo-Json -InputObject $listRouteTables -Depth 7 | Out-File "routeTables.json"
ConvertTo-Json -InputObject $listNsgs -Depth 7 | Out-File "nsgs.json"
ConvertTo-Json -InputObject $listFirewalls -Depth 7 | Out-File "firewalls.json"
ConvertTo-Json -InputObject $listNatGateways -Depth 7 | Out-File "natGateways.json"
ConvertTo-Json -InputObject $listAppGateways -Depth 7 | Out-File "appGateways.json"
ConvertTo-Json -InputObject $listVnetGateways -Depth 7 | Out-File "vnetGateways.json"
ConvertTo-Json -InputObject $listExpressRouteGateways -Depth 7 | Out-File "expressRouteCircuits.json"
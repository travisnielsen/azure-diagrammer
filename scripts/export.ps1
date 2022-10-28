# load subscription and tenant IDs
$contextInfo = Get-Content ./config.json | ConvertFrom-Json
$azContext = Get-AzContext
$outFolder = $contextInfo.subscriptionId
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


# identify other subscriptions based on VNET Gateway Connection objects
# ExpressRoute circuits are often placed in separate / isolated subscriptions

$listGatewayConnections = New-Object -TypeName 'System.Collections.ArrayList'

foreach ($subscription in $listSubscriptions | Select-Object -Unique) {
    Set-AzContext -Subscription $subscription
    Get-AzResource -ResourceType "Microsoft.Network/connections" -ExpandProperties | ForEach-Object { $listGatewayConnections.Add($_) }
    
    foreach ($connection in $listGatewayConnections) {
        $connectionPeerId = $connection.properties.peer.id

        # Only concerned about ER circuits in isolated subscriptions

        if ($connectionPeerId) {
            $connectionPeerSubscriptionId = $connectionPeerId.Split("/")[2]
            if ($subscriptions -notcontains $connectionPeerSubscriptionId) {
                $listSubscriptions.Add($connectionPeerSubscriptionId)
            }
        }
    }
}

# Export objects in-scope for the identified subscriptions based on VNETs and VNET Connection objects

$subscriptions = $listSubscriptions | Select-Object -Unique
$listSubscriptionInfo = New-Object -TypeName 'System.Collections.ArrayList'
$listRouteTables = New-Object -TypeName 'System.Collections.ArrayList'
$listNsgs = New-Object -TypeName 'System.Collections.ArrayList'
$listFirewalls = New-Object -TypeName 'System.Collections.ArrayList'
$listNatGateways = New-Object -TypeName 'System.Collections.ArrayList'
$listAppGateways = New-Object -TypeName 'System.Collections.ArrayList'
$listVnetGateways = New-Object -TypeName 'System.Collections.ArrayList'
$listExpressRouteCircuits = New-Object -TypeName 'System.Collections.ArrayList'

foreach ($subscription in $subscriptions) {
    Set-AzContext -Subscription $subscription
    $context = Get-AzContext
    $listSubscriptionInfo.Add($context.Subscription)

    Get-AzResource -ResourceType "Microsoft.Network/routeTables" -ExpandProperties | ForEach-Object { $listRouteTables.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/networkSecurityGroups" -ExpandProperties | ForEach-Object { $listNsgs.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/azureFirewalls" -ExpandProperties | ForEach-Object { $listFirewalls.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/natGateways" -ExpandProperties | ForEach-Object { $listNatGateways.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/applicationGateways" -ExpandProperties | ForEach-Object { $listAppGateways.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/virtualNetworkGateways" -ExpandProperties | ForEach-Object { $listVnetGateways.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/expressRouteCircuits" -ExpandProperties | ForEach-Object { $listExpressRouteCircuits.Add($_) }
}

New-Item -Path "..//data/${outFolder}" -ItemType Directory
ConvertTo-Json -InputObject $listSubscriptionInfo -Depth 7 | Out-File "..//data/${outFolder}/subscriptions.json"
ConvertTo-Json -InputObject $listVnets -Depth 7 | Out-File "..//data/${outFolder}/vnets.json"
ConvertTo-Json -InputObject $listRouteTables -Depth 7 | Out-File "..//data/${outFolder}/routeTables.json"
ConvertTo-Json -InputObject $listNsgs -Depth 7 | Out-File "..//data/${outFolder}/nsgs.json"
ConvertTo-Json -InputObject $listFirewalls -Depth 7 | Out-File "..//data/${outFolder}/firewalls.json"
ConvertTo-Json -InputObject $listNatGateways -Depth 7 | Out-File "..//data/${outFolder}/natGateways.json"
ConvertTo-Json -InputObject $listAppGateways -Depth 7 | Out-File "..//data/${outFolder}/appGateways.json"
ConvertTo-Json -InputObject $listVnetGateways -Depth 7 | Out-File "..//data/${outFolder}/vnetGateways.json"
ConvertTo-Json -InputObject $listGatewayConnections -Depth 7 | Out-File "..//data/${outFolder}/connections.json"
ConvertTo-Json -InputObject $listExpressRouteCircuits -Depth 7 | Out-File "..//data/${outFolder}/expressRouteCircuits.json"
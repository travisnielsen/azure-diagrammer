# get connection context
$contextInfo = Get-Content ./config-v2.json | ConvertFrom-Json
Connect-AzAccount -Tenant $contextInfo.tenantId
$azContext = Get-AzContext
$outFolder = "..//data/" + $contextInfo.subscriptionName
$listSubscriptions = New-Object -TypeName 'System.Collections.ArrayList'

if ($null -eq $azContext) {
    Connect-AzAccount -Subscription $contextInfo.subscriptionName -Tenant $contextInfo.tenantId
    $listSubscriptions.Add($contextInfo.subscriptionName)
} else {
    Set-AzContext -Subscription $contextInfo.subscriptionName
    $listSubscriptions.Add($contextInfo.subscriptionName)
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
    $remoteNetworksubscriptionName = $vnetId.split("/")[2]
    $currentContext = Get-AzContext

    if ($remoteNetworksubscriptionName -ne $currentContext.Subscription.Id ) {
        Set-AzContext -Subscription $remoteNetworksubscriptionName
        $listSubscriptions.Add($remoteNetworksubscriptionName)
    }

    $remoteVnet = Get-AzResource -ResourceId $vnetId -ExpandProperties
    $listVnets.Add($remoteVnet)
}

$subscriptions = $listSubscriptions | Select-Object -Unique
$listSubscriptionInfo = New-Object -TypeName 'System.Collections.ArrayList'
$listRouteTables = New-Object -TypeName 'System.Collections.ArrayList'
$listFirewalls = New-Object -TypeName 'System.Collections.ArrayList'
$listNatGateways = New-Object -TypeName 'System.Collections.ArrayList'
$listVnetGateways = New-Object -TypeName 'System.Collections.ArrayList'
$listExpressRouteCircuits = New-Object -TypeName 'System.Collections.ArrayList'

foreach ($subscription in $subscriptions) {
    Set-AzContext -Subscription $subscription
    $context = Get-AzContext
    $listSubscriptionInfo.Add($context.Subscription)

    Get-AzResource -ResourceType "Microsoft.Network/routeTables" -ExpandProperties | ForEach-Object { $listRouteTables.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/azureFirewalls" -ExpandProperties | ForEach-Object { $listFirewalls.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/natGateways" -ExpandProperties | ForEach-Object { $listNatGateways.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/virtualNetworkGateways" -ExpandProperties | ForEach-Object { $listVnetGateways.Add($_) }
    Get-AzResource -ResourceType "Microsoft.Network/expressRouteCircuits" -ExpandProperties | ForEach-Object { $listExpressRouteCircuits.Add($_) }
}

#
# Azure services (Compute, Data, Storage, etc...)
#

Set-AzContext -Subscription $contextInfo.subscriptionName
$services = $contextInfo.services
$dictServices = @{}

foreach ($service in $services) {
    $items = Get-AzResource -ResourceType "${service}" -ExpandProperties
    $dictServices.add( $service, $items)
}

#
# Write out data
#

New-Item -Path "..//data/${outFolder}" -ItemType Directory -ErrorAction Ignore

ConvertTo-Json -InputObject $listSubscriptionInfo -Depth 7 | Out-File "..//data/${outFolder}/subscriptions.json"
ConvertTo-Json -InputObject $listVnets -Depth 7 | Out-File "..//data/${outFolder}/vnets.json"
ConvertTo-Json -InputObject $listRouteTables -Depth 7 | Out-File "..//data/${outFolder}/routeTables.json"
ConvertTo-Json -InputObject $listFirewalls -Depth 7 | Out-File "..//data/${outFolder}/firewalls.json"
ConvertTo-Json -InputObject $listNatGateways -Depth 7 | Out-File "..//data/${outFolder}/natGateways.json"
ConvertTo-Json -InputObject $listVnetGateways -Depth 7 | Out-File "..//data/${outFolder}/vnetGateways.json"
ConvertTo-Json -InputObject $listGatewayConnections -Depth 7 | Out-File "..//data/${outFolder}/connections.json"
ConvertTo-Json -InputObject $listExpressRouteCircuits -Depth 7 | Out-File "..//data/${outFolder}/expressRouteCircuits.json"

$dictServices.GetEnumerator() | ForEach-Object {
    $filename = $_.key.Split("/")[1]
    ConvertTo-Json -InputObject $_.value -Depth 7 | Out-File "..//data/${outFolder}/${filename}.json"
}

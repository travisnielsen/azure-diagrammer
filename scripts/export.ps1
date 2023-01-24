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

    # get network rules for Event Hub and Service Bus
    if ($service -eq "Microsoft.EventHub/namespaces" -or $service -eq "Microsoft.ServiceBus/namespaces") {

        $networkRuleSets = New-Object -TypeName 'System.Collections.ArrayList'
        $namespace = ""

        foreach ($item in $items) {
            if ($service -eq "Microsoft.EventHub/namespaces") {
                $networkRuleSet = Get-AzEventHubNetworkRuleSet -ResourceGroupName $item.ResourceGroupName -Namespace $item.Name
                $networkRuleSets.Add($networkRuleSet)
                $namespace = "Microsoft.EventHub/Namespaces/NetworkRuleSets"
            }
            if ($service -eq "Microsoft.ServiceBus/namespaces") {
                $networkRuleSet = Get-AzServiceBusNetworkRuleSet -ResourceGroupName $item.ResourceGroupName -Namespace $item.Name
                $networkRuleSets.Add($networkRuleSet)
                $namespace = "Microsoft.ServiceBus/Namespaces/NetworkRuleSets"
            }
        }

        $dictServices.add($namespace, $networkRuleSets)
    }
}

#
# Write out data
#

New-Item -Path "..//data/${outFolder}" -ItemType Directory -ErrorAction Ignore

ConvertTo-Json -InputObject $listSubscriptionInfo -Depth 20 | Out-File "..//data/${outFolder}/subscriptions.json"
ConvertTo-Json -InputObject $listVnets -Depth 20 | Out-File "..//data/${outFolder}/vnets.json"
ConvertTo-Json -InputObject $listRouteTables -Depth 20 | Out-File "..//data/${outFolder}/routeTables.json"
ConvertTo-Json -InputObject $listFirewalls -Depth 20 | Out-File "..//data/${outFolder}/firewalls.json"
ConvertTo-Json -InputObject $listNatGateways -Depth 20 | Out-File "..//data/${outFolder}/natGateways.json"
ConvertTo-Json -InputObject $listVnetGateways -Depth 20 | Out-File "..//data/${outFolder}/vnetGateways.json"
ConvertTo-Json -InputObject $listGatewayConnections -Depth 20 | Out-File "..//data/${outFolder}/gatewayConnections.json"
ConvertTo-Json -InputObject $listExpressRouteCircuits -Depth 20 | Out-File "..//data/${outFolder}/expressRouteCircuits.json"

$dictServices.GetEnumerator() | ForEach-Object {
    $filename = $_.key.Split("/")[1]

    switch ($_.Key)
    {
        "Microsoft.ServiceBus/namespaces" { $filename = "serviceBusNamespaces"; Break }
        "Microsoft.ServiceBus/namespaces/NetworkRuleSets" { $filename = "serviceBusNetworkRuleSets"; Break }
        "Microsoft.EventHub/clusters" { $filename = "eventHubClusters"; Break }
        "Microsoft.EventHub/namespaces" { $filename = "eventHubNamespaces"; Break }
        "Microsoft.EventHub/namespaces/NetworkRuleSets" { $filename = "eventHubNetworkRuleSets"; Break }
        "Microsoft.ApiManagement/service" { $filename = "apiManagement"; Break }
        "Microsoft.ContainerService/managedClusters" { $filename = "apiManagement"; Break }
        "Microsoft.DocumentDB/databaseAccounts" { $filename = "cosmosDbAccounts"; Break }
        "Microsoft.ContainerService/managedClusters" { $filename = "azureKubernetesService"; Break }
    }

    ConvertTo-Json -InputObject $_.value -Depth 20 | Out-File "..//data/${outFolder}/${filename}.json"
}

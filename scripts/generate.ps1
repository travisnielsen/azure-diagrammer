$dictData = @{}
$sourceFiles = Get-ChildItem -Path '..//data'

foreach ($file in $sourceFiles) {
    $dataItems = Get-Content $file.PSPath | ConvertFrom-Json
    $dictData.add( $file.BaseName, $dataItems)
}

$diagram = Get-Content '..//templates/diagram.puml' -Raw
$subscriptionTemplate = Get-Content '..//templates/subscription.puml'
$regionTemplate = Get-Content '..//templates/region.puml' -Raw
$vnetTemplate = Get-Content '..//templates/vnet.puml' -Raw
$subnetTemplate = Get-Content '..//templates/subnet.puml' -Raw
$routeTableTemplate = Get-Content '..//templates/routeTable.puml' -Raw
$nsgTemplate = Get-Content '..//templates/nsg.puml' -Raw
$vnetGatewayTemplate = Get-Content '..//templates/vnetGateway.puml' -Raw
$expressRouteTemplate = Get-Content '..//templates/expressRoute.puml' -Raw
$firewallTemplate = Get-Content '..//templates/firewall.puml' -Raw

$gatewayConnections = New-Object -TypeName 'System.Collections.ArrayList'

$diagramContent = ""

$regions = @( $dictData['vnets'] | ForEach-Object {$_.Location } ) | Select-Object -Unique
$subscriptions = @($dictData['subscriptions'])
$dictGatewayMarkupNames = @{}

# region

foreach ($regionName in $regions) {
    $regionData = $regionTemplate
    $regionData = $regionData.Replace("[id]", $regionName)
    $regionData = $regionData.Replace("[name]", "`"{0}`"" -f $regionName)
    $subscriptionsMarkupContainer = ''
    $subscriptionMarkupIdList = New-Object -TypeName 'System.Collections.ArrayList'

    # subscriptions

    foreach ($subscription in $subscriptions) {

        # keep track of the # of services in the subscription
        $serviceCount = 0

        $subscriptionServicesMarkupContainer = ''

        $subscriptionMarkup = $subscriptionTemplate
        $subscriptionMarkupId = $regionName + $subscription.Name.Replace("-", "")
        # $subscriptionMarkupIdList.Add($subscriptionMarkupId)
        $subscriptionMarkup = $subscriptionMarkup.Replace("[id]", $subscriptionMarkupId)
        $subscriptionMarkup = $subscriptionMarkup.Replace("[name]", "`"{0}`"" -f $subscription.Name)
        $subscriptionMarkup = $subscriptionMarkup.Replace("[technology]", "`"{0}`"" -f $subscription.Id)
        $subscriptionMarkup = $subscriptionMarkup.Replace("[description]", "`"{0}`"" -f "TBD")

        $vnets = $dictData['vnets'] | Where-Object { $_.Location -eq $regionName -and $_.SubscriptionId -eq $subscription.Id }

        foreach ($vnet in $vnets) {
            $serviceCount +=1
            $isHub = $false
            $subnetMarkupIds = New-Object -TypeName 'System.Collections.ArrayList'
            $vnetMarkup = $vnetTemplate
            $descriptionText = ""
    
            if ($vnet.Properties.virtualNetworkPeerings.Count -gt 2) {
                $isHub = $true
            }
    
            # DNS settings
            $dnsSettings = $vnet.Properties.dhcpOptions.dnsServers
    
            if ($dnsSettings.Length -gt 0) {
                foreach ($dnsServer in $dnsSettings) { $descriptionText += $dnsServer + " " }
            } else {
                $descriptionText += "Azure Resolver"
            }
    
            $vnetMarkup = $vnetMarkup.Replace("[id]", $vnet.Name.Replace("-", ""))
            $vnetMarkup = $vnetMarkup.Replace("[name]", "`"{0}`"" -f $vnet.Name)
            $vnetMarkup = $vnetMarkup.Replace("[technology]", "`"{0}`"" -f $vnet.Properties.addressSpace.addressPrefixes)
            $vnetMarkup = $vnetMarkup.Replace("[description]", "`"DNS: {0}`"" -f $descriptionText)
            $subnetMarkupContainer = ''
    
            foreach ($subnet in $vnet.Properties.subnets) {
                $isHubSubnet = $false
                $subnetMarkup = $subnetTemplate
                $subnetMarkupId = $subnet.name.Replace("-", "")
    
                if ($subnet.name -eq "GatewaySubnet" -or $subnet.name -eq "AzureFirewallSubnet") {
                    $subnetMarkupId = $subnetMarkupId + $vnet.Name.Replace("-", "")
                    $isHubSubnet = $true
                }
    
                # for hub vnets, don't add hub subnets that are not related to connectivity
                if ($isHub -and ($isHubSubnet -eq $false)) { break }
    
                $subnetMarkup = $subnetMarkup.Replace("[id]", $subnetMarkupId)
                $subnetMarkup = $subnetMarkup.Replace("[name]", "`"{0}`"" -f $subnet.name)
                $subnetMarkup = $subnetMarkup.Replace("[technology]", "`"{0}`"" -f $subnet.properties.addressPrefix)
                $subnetMarkup = $subnetMarkup.Replace("[description]", "`"{0}`"" -f "demo")
    
                $subnetServicesMarkup = ""
    
                $routeTableId = $subnet.properties.routeTable.id
    
                if ($null -ne $routeTableId) {
                    $routeTable = $dictData['routeTables'] | Where-Object { $_.Id -eq $routeTableId }
                    $routeTableMarkup = "`t`t`t`t" + $routeTableTemplate
                    $routeTableMarkup = $routeTableMarkup.Replace("[id]", $routeTable.name.Replace("-", ""))
                    $routeTableMarkup = $routeTableMarkup.Replace("[name]", "`"{0}`"" -f $routeTable.name)
                    $routeTableMarkup = $routeTableMarkup.Replace("[technology]", "`"{0}`"" -f "TBD")
                    $routeTableMarkup = $routeTableMarkup.Replace("[description]", "`"{0}`"" -f "demo")
                    $subnetServicesMarkup += $routeTableMarkup + "`n"
                }
    
                $nsgId = $subnet.properties.networkSecurityGroup.id
    
                if ($null -ne $nsgId) {
                    $nsg = $dictData['nsgs'] | Where-Object { $_.Id -eq $nsgId }
                    $nsgMarkup = "`t`t`t`t" + $nsgTemplate
                    $nsgMarkup = $nsgMarkup.Replace("[id]", $nsg.name.Replace("-", ""))
                    $nsgMarkup = $nsgMarkup.Replace("[name]", "`"{0}`"" -f $nsg.name)
                    $nsgMarkup = $nsgMarkup.Replace("[technology]", "`"{0}`"" -f "TBD")
                    $nsgMarkup = $nsgMarkup.Replace("[description]", "`"{0}`"" -f "demo")
                    $subnetServicesMarkup += $nsgMarkup + "`n"
                }
    
                $vnetGateway = $dictData["vnetGateways"] | Where-Object { $_.Properties.ipConfigurations[0].properties.subnet.id -eq $subnet.id }
    
                if ($vnetGateway) {
                    $gatewayMarkup = "`t`t`t`t" + $vnetGatewayTemplate

                    $gatewayMarkupId = $vnetGateway.name.Replace("-", "")
                    $dictGatewayMarkupNames.Add($vnetGateway.Id, $gatewayMarkupId)

                    $gatewayMarkup = $gatewayMarkup.Replace("[id]", $gatewayMarkupId )
                    $gatewayMarkup = $gatewayMarkup.Replace("[name]", "`"{0}`"" -f $vnetGateway.name)
                    $technologyText = "SKU: {0}, Capacity: {1}" -f $vnetGateway.Properties.sku.name, $vnetGateway.Properties.sku.capacity
                    $gatewayMarkup = $gatewayMarkup.Replace("[technology]", "`"{0}`"" -f $technologyText)
                    $gatewayMarkup = $gatewayMarkup.Replace("[description]", "`"{0}`"" -f $vnetGateway.Properties.gatewayType)
                    $subnetServicesMarkup += $gatewayMarkup + "`n"

                    # Add gateway connection to global list
                    $dictData["connections"] | Where-Object { $_.Properties.virtualNetworkGateway1.id -eq $vnetGateway.Id } | ForEach-Object { $gatewayConnections.Add($_) }
                }

                $firewall = $dictData["firewalls"] | Where-Object { $_.Properties.ipConfigurations[0].properties.subnet.id -eq $subnet.id }
    
                if ($firewall) {
                    $firewallMarkup = "`t`t`t`t" + $firewallTemplate
                    $firewallMarkup = $firewallMarkup.Replace("[id]", $firewall.name.Replace("-", ""))
                    $firewallMarkup = $firewallMarkup.Replace("[name]", "`"{0}`"" -f $firewall.name)
                    $firewallMarkup = $firewallMarkup.Replace("[technology]", "`"SKU: {0}`"" -f $firewall.Properties.sku.tier)
                    $firewallMarkup = $firewallMarkup.Replace("[description]", "`"<B>{0}</B>`"" -f $firewall.Properties.ipConfigurations[0].properties.privateIPAddress )
                    $subnetServicesMarkup += $firewallMarkup + "`n"         
                }
    
                # append markup to subnet
                if ($subnetServicesMarkup) {
                    $subnetMarkup += " {`n"
                    $subnetMarkup += $subnetServicesMarkup
                    $subnetMarkup += "`t`t`t}`n"
                }
    
                $subnetMarkupContainer += "`n"
                $subnetMarkupContainer += "`t`t`t" + $subnetMarkup
    
                $subnetMarkupIds.Add($subnetMarkupId)
            }
    
            # append markup for vertical alignment of subnets
            $hiddenLinkMarkup = "`n"
    
            for ($i=0; $i -lt $subnetMarkupIds.Count; $i++) {
                if ($i -gt 0) {
                    $hiddenLinkMarkup += "`t`t`t{0} -[hidden]d-> {1}`n" -f $subnetMarkupIds[$i-1], $subnetMarkupIds[$i]
                }
            }
            
            $subnetMarkupContainer += $hiddenLinkMarkup
    
            # insert vnet data
            $vnetMarkup = $vnetMarkup.Replace("[subnets]", $subnetMarkupContainer)
            $subscriptionServicesMarkupContainer += "`n"
            $subscriptionServicesMarkupContainer += $vnetMarkup + "`n"
        }

        if ($serviceCount -gt 0) {
            $subscriptionMarkupIdList.Add($subscriptionMarkupId)
            $subscriptionMarkup = $subscriptionMarkup.Replace("[services]", $subscriptionServicesMarkupContainer)
            $subscriptionsMarkupContainer += "`n" + $subscriptionMarkup
        }

    } # end subscription

    # directional relationship between subscriptions
    $hiddenSubscriptionLinkMarkup = "`n"

    for ($i=0; $i -lt $subscriptionMarkupIdList.Count; $i++) {
        if ($i -gt 0) {
            $hiddenSubscriptionLinkMarkup += "`t`t{0} -----[hidden]d-> {1}`n" -f $subscriptionMarkupIdList[$i-1], $subscriptionMarkupIdList[$i]
        }
    }

    $subscriptionsMarkupContainer += $hiddenSubscriptionLinkMarkup

    # $regionData += "`n"
    $regionData = $regionData.Replace("[subscriptions]", $subscriptionsMarkupContainer)
    $diagramContent += "`n`n"
    $diagramContent += $regionData
}


# VNET Peerings

$dictPeerings = @{}
$vnetPeerings = "`n"
$vnetIds = @( $dictData['vnets'] | ForEach-Object {$_.Name } )

foreach($vnet in $dictData['vnets']) {

    if ($vnet.Properties.virtualNetworkPeerings.Count -gt 0) {

        foreach($peering in $vnet.Properties.virtualNetworkPeerings) {

            $remoteVnetId = $peering.properties.remoteVirtualNetwork.id.Split("/")[8]

            if ($remoteVnetId -in $vnetIds ) {
                # check to see if there is already a peering. No need to complicate the diagram with bi-directional peering
                if (! $dictPeerings.ContainsKey($remoteVnetId)) {
                    $peeringMarkup = "{0} <-> {1}" -f $vnet.Name.Replace("-", ""), $remoteVnetId.Replace("-", "")
                    $vnetPeerings += "`n" + $peeringMarkup
                    $dictPeerings.Add($vnet.Name, $remoteVnetId)
                }
            }
        }
    }
}

# ==========================
# add ExpressRoute circuits

$hybridConnectivityMarkup = ''
$circuitLinksMarkup = ''
$circuitsIds = $gatewayConnections | ForEach-Object { $_.Properties.peer.id } | Select-Object -Unique
$expressRouteCircuits = $dictData['expressRouteCircuits'] | Where-Object { $_.ResourceId -in $circuitsIds }
$expressRouteSubscriptionIds = $expressRouteCircuits | ForEach-Object { $_.SubscriptionId } | Select-Object -Unique
$expressRouteSubscriptions = $subscriptions | Where-Object { $_.Id -in $expressRouteSubscriptionIds }

foreach ($subscrption in $expressRouteSubscriptions) {

    # add the subscription container markup
    $subscriptionMarkup = "`n" + $subscriptionTemplate
    $subscriptionMarkupId = $subscription.Name.Replace("-", "")
    $subscriptionMarkup = $subscriptionMarkup.Replace("[id]", $subscriptionMarkupId)
    $subscriptionMarkup = $subscriptionMarkup.Replace("[name]", "`"{0}`"" -f $subscription.Name)
    $subscriptionMarkup = $subscriptionMarkup.Replace("[technology]", "`"{0}`"" -f $subscription.Id)
    $subscriptionMarkup = $subscriptionMarkup.Replace("[description]", "`"{0}`"" -f "TBD")

    # add expressroute circuits
    $circuitsMarkup = ''
    $circuits = $expressRouteCircuits | Where-Object { $_.SubscriptionId -eq $subscription.Id }

    foreach ($circuit in $circuits) {
        $expressRouteMarkup = $expressRouteTemplate
        $expressRouteMarkupId = $circuit.Name.Replace("-", "")
        $expressRouteMarkup = $expressRouteMarkup.Replace("[id]", $expressRouteMarkupId)
        $expressRouteMarkup = $expressRouteMarkup.Replace("[name]", "`"{0}`"" -f $circuit.Name)

        $technologyText = ''
        $technologyText += $circuit.Sku.Tier + " " + $circuit.Sku.Family
        $expressRouteMarkup = $expressRouteMarkup.Replace("[technology]", $technologyText )

        $descriptionText = ''
        $descriptionText += "Provider: " + $circuit.Properties.serviceProviderProperties.serviceProviderName + "\n"
        $descriptionText += "Peering Location: " + $circuit.Properties.serviceProviderProperties.peeringLocation + "\n"
        $descriptionText += "Bandwidth (Mbps): " + $circuit.Properties.serviceProviderProperties.bandwidthInMbps
        $expressRouteMarkup = $expressRouteMarkup.Replace("[description]", "`"{0}`"" -f $descriptionText)
        $circuitsMarkup += "`n" + $expressRouteMarkup + "`n"

        # link circuit to gateways
        $expressRouteConnections = $gatewayConnections | Where-Object { $_.Properties.peer.id -eq $circuit.Id }

        foreach ($connection in $expressRouteConnections) {
            # get remote gateway markup ID
            $gatewayMarkupId = $dictGatewayMarkupNames[$connection.Properties.virtualNetworkGateway1.id]

            if ($gatewayMarkupId) {
                $circuitLinksMarkup += "{0} <-----> {1}" -f $gatewayMarkupId, $expressRouteMarkupId
                $circuitLinksMarkup += "`n"
            }
        }


    }

    # add markup
    $subscriptionMarkup = $subscriptionMarkup.Replace("[services]", $circuitsMarkup)
    $hybridConnectivityMarkup += "`n" + $subscriptionMarkup + "`n"
    $hybridConnectivityMarkup += $circuitLinksMarkup

}

# end ExpressRoute circuits
# =========================

$diagramContent += $vnetPeerings

$diagramContent += $hybridConnectivityMarkup

$diagram = $diagram.Replace("[BODY]", $diagramContent)
$diagram = $diagram.Replace("[TITLE]", "sample-diagram")
$diagram | Out-File "network-diag.puml"
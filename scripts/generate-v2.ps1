Import-Module -Name .\scripts.psd1 -Force

$dictData = @{}
$contextInfo = Get-Content ./config-v2.json | ConvertFrom-Json
$folder = $contextInfo.subscriptionName
$diagramFileName = $folder + ".puml"
$sourceFiles = Get-ChildItem -Path "..//data/${folder}"

foreach ($file in $sourceFiles) {
    $dataItems = Get-Content $file.PSPath | ConvertFrom-Json
    $dictData.add( $file.BaseName, $dataItems)
}

$regionName = $contextInfo.region

$expressRouteColors = @('red','orange','purple','aqua')

$diagram = Get-Content './templates/diagram.puml' -Raw
$regionTemplate = Get-Content './templates/region-v2.puml' -Raw
$subscriptionTemplate = Get-Content './templates/subscription.puml'
$vnetTemplate = Get-Content './templates/vnet.puml' -Raw
$subnetTemplate = Get-Content './templates/subnet.puml' -Raw
$expressRouteTemplate = Get-Content './templates/expressRoute.puml' -Raw

$gatewayConnections = New-Object -TypeName 'System.Collections.ArrayList'
$diagramContent = ""
$subscriptions = @($dictData['subscriptions'])
$dictGatewayMarkupNames = @{}

$regionMarkup = $regionTemplate

$subscriptionsMarkupContainer = ''
$subscriptionMarkupIdList = New-Object -TypeName 'System.Collections.ArrayList'


# subscriptions

foreach ($subscription in $subscriptions) {
    $subscriptionServicesMarkupContainer = ''
    $subscriptionMarkup = $subscriptionTemplate
    $subscriptionMarkupId = $regionName + $subscription.Name.Replace("-", "")
    $subscriptionMarkup = $subscriptionMarkup.Replace("[id]", $subscriptionMarkupId)
    $subscriptionMarkup = $subscriptionMarkup.Replace("[name]", "`"{0}`"" -f $subscription.Name)
    $subscriptionMarkup = $subscriptionMarkup.Replace("[technology]", "`"{0}`"" -f $subscription.Id)
    $subscriptionMarkup = $subscriptionMarkup.Replace("[description]", "`"{0}`"" -f "TBD")

    $vnetMarkupList = New-Object -TypeName 'System.Collections.ArrayList'

    $vnets = $dictData['vnets'] | Where-Object { $_.Location -eq $regionName -and $_.SubscriptionId -eq $subscription.Id }

    foreach ($vnet in $vnets) {
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

        # higlight peered VNETs
        if ($vnet.Properties.virtualNetworkPeerings.Count -gt 0) {
            $vnetMarkup = $vnetMarkup.Replace("[style]", "<<peered>>")
        } else {
            $vnetMarkup = $vnetMarkup.Replace("[style]", "")
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
            $subnetMarkup = $subnetMarkup.Replace("[technology]", "null")
            $subnetMarkup = $subnetMarkup.Replace("[description]", "`"{0}`"" -f $subnet.properties.addressPrefix)

            $subnetServicesMarkup = ""

            $routeTableId = $subnet.properties.routeTable.id
            if ($null -ne $routeTableId) {
                $routeTable = $dictData['routeTables'] | Where-Object { $_.Id -eq $routeTableId }
                $routeTableMarkup = Get-RouteTableMarkup $routeTable
                $subnetServicesMarkup += $routeTableMarkup + "`n"
            }

            $nsgId = $subnet.properties.networkSecurityGroup.id
            if ($null -ne $nsgId) {
                $nsg = $dictData['networkSecurityGroups'] | Where-Object { $_.Id -eq $nsgId }
                $nsgMarkup = Get-NsgMarkup $nsg
                $subnetServicesMarkup += $nsgMarkup + "`n"                
            }

            $vnetGateway = $dictData["vnetGateways"] | Where-Object { $_.Properties.ipConfigurations[0].properties.subnet.id -eq $subnet.id }
            if ($vnetGateway) {
                $gatewayMarkupId = $vnetGateway.name.Replace("-", "")
                $dictGatewayMarkupNames.Add($vnetGateway.Id, $gatewayMarkupId)
                $gatewayMarkup = Get-VnetGatewayMarkup $vnetGateway
                $subnetServicesMarkup += $gatewayMarkup + "`n"

                # Add gateway connection to global list
                $dictData["gatewayConnections"] | Where-Object { $_.Properties.virtualNetworkGateway1.id -eq $vnetGateway.Id } | ForEach-Object { $gatewayConnections.Add($_) }
            }

            $firewall = $dictData["firewalls"] | Where-Object { $_.Properties.ipConfigurations[0].properties.subnet.id -eq $subnet.id }
            if ($firewall) {
                $firewallMarkup = Get-FirewallMarkup $firewall
                $subnetServicesMarkup += $firewallMarkup + "`n"     
            }

            $loadBalancers = $dictData["loadBalancers"] | Where-Object { $_.Properties.frontendIPConfigurations[0].properties.subnet.id -eq $subnet.id }
            if ($loadBalancers) {
                foreach ($lb in $loadBalancers) {
                    $loadBalancerMarkup = Get-LoadBalancerMarkup $lb
                    $subnetServicesMarkup += $loadBalancerMarkup + "`n"   
                }
            }

            $apimInstances = $dictData["apiManagement"] | Where-Object { $_.Properties.virtualNetworkConfiguration.subnetResourceId -eq $subnet.id }
            if ($apimInstances) {
                foreach ($apim in $apimInstances) {
                    $apimMarkup = Get-ApimMarkup $apim
                    $subnetServicesMarkup += $apimMarkup + "`n"
                }
            }

            $databricksWorkspacePrivate = $dictData["workspaces"] | Where-Object { $_.Properties.parameters.customPrivateSubnetName.value -eq $subnet.name }
            if ($databricksWorkspacePrivate) {
                $dataBricksMarkup = Get-DataBricksMarkup $databricksWorkspacePrivate $true
                $subnetServicesMarkup += $dataBricksMarkup + "`n"
            }

            $databricksWorkspacePublic = $dictData["workspaces"] | Where-Object { $_.Properties.parameters.customPublicSubnetName.value -eq $subnet.name }
            if ($databricksWorkspacePublic) {
                $dataBricksMarkup = Get-DataBricksMarkup $databricksWorkspacePublic $false
                $subnetServicesMarkup += $dataBricksMarkup + "`n"
            }



            # append markup to subnet
            if ($subnetServicesMarkup) {
                $subnetMarkup += " {`n"
                $subnetMarkup += $subnetServicesMarkup
                $subnetMarkup += "`t`t`t}`n"
            }

            $subnetMarkupContainer += "`n"
            $subnetMarkupContainer += $subnetMarkup
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
        $vnetMarkupList.Add($vnetMarkup)
    } # end VNETs

    <#
    # append VNET data
    foreach ($markup in $vnetMarkupList) {
        $subscriptionServicesMarkupContainer += "`n"
        $subscriptionServicesMarkupContainer += $markup + "`n"    
    }
    #>

    # append VNETs in order of peering status

    $islandVnetMarkup = $vnetMarkupList | Where-Object { $_ -notlike "*<<peered>>*"}
    foreach ($markup in $islandVnetMarkup) {      
        $subscriptionServicesMarkupContainer += "`n"
        $subscriptionServicesMarkupContainer += $markup + "`n"     
    }

    $peeredVnetMarkup = $vnetMarkupList | Where-Object { $_ -like "*<<peered>>*"}
    foreach ($markup in $peeredVnetMarkup) {      
        $subscriptionServicesMarkupContainer += "`n"
        $subscriptionServicesMarkupContainer += $markup + "`n"     
    }


    #
    # Azure Services (non-vnet integrated)
    #




    $subscriptionMarkupIdList.Add($subscriptionMarkupId)
    $subscriptionMarkup = $subscriptionMarkup.Replace("[services]", $subscriptionServicesMarkupContainer)
    $subscriptionsMarkupContainer += "`n" + $subscriptionMarkup

} # end subscription

$regionMarkup = $regionMarkup.Replace("[subscriptions]", $subscriptionsMarkupContainer)
$diagramContent += "`n`n"
$diagramContent += $regionMarkup


# directional relationship between subscriptions
$hiddenSubscriptionLinkMarkup = "`n"

for ($i=0; $i -lt $subscriptionMarkupIdList.Count; $i++) {
    if ($i -gt 0) {
        $hiddenSubscriptionLinkMarkup += "`t`t{0} --------[hidden]d-> {1}`n" -f $subscriptionMarkupIdList[$i-1], $subscriptionMarkupIdList[$i]
    }
}

$subscriptionsMarkupContainer += $hiddenSubscriptionLinkMarkup

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
                    $peeringMarkup = "{0} -[thickness=16,dashed,#ffb86c] {1}" -f $vnet.Name.Replace("-", ""), $remoteVnetId.Replace("-", "")
                    $vnetPeerings += "`n" + $peeringMarkup
                    $dictPeerings.Add($vnet.Name, $remoteVnetId)
                }
            }
        }
    }
}

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
    $circuitId = 0

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
        
        $lineColor = $expressRouteColors[$circuitId]
        
        $lineThickness = 3
        $bandwidthMbps = $circuit.Properties.serviceProviderProperties.bandwidthInMbps
        switch ($bandwidthMbps) {
            5000 { $lineThickness = 4 }
            10000 { $lineThickness = 5 }
            default { $lineThickness = 3 }
        }

        foreach ($connection in $expressRouteConnections) {
            # get remote gateway markup ID
            $gatewayMarkupId = $dictGatewayMarkupNames[$connection.Properties.virtualNetworkGateway1.id]

            $routingWeight = $connection.Properties.routingWeight

            if ($gatewayMarkupId) {
                $circuitLinksMarkup += "{0} -[thickness=${lineThickness},#${lineColor}]---- {1}" -f $gatewayMarkupId, $expressRouteMarkupId
                $circuitLinksMarkup += " : `"=Routing weight - {0}`"\n" -f $routingWeight
                $circuitLinksMarkup += "`n"
            }
        }

        $circuitId += 1

    } # end ExpressRoute circuit

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
$diagram = $diagram.Replace("[TITLE]", $folder)
$diagram | Out-File $diagramFileName
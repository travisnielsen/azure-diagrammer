$dictData = @{}
$sourceFiles = Get-ChildItem -Path '..//data'

foreach ($file in $sourceFiles) {
    $dataItems = Get-Content $file.PSPath | ConvertFrom-Json
    $dictData.add( $file.BaseName, $dataItems)
}

$diagram = Get-Content '..//templates/diagram.puml' -Raw
$regionTemplate = Get-Content '..//templates/region.puml' -Raw
$vnetTemplate = Get-Content '..//templates/vnet.puml' -Raw
$subnetTemplate = Get-Content '..//templates/subnet.puml' -Raw
$routeTableTemplate = Get-Content '..//templates/routeTable.puml' -Raw
$nsgTemplate = Get-Content '..//templates/nsg.puml' -Raw
$vnetGatewayTemplate = Get-Content '..//templates/vnetGateway.puml' -Raw
$firewallTemplate = Get-Content '..//templates/firewall.puml' -Raw

$diagramContent = ""

$regions = @( $dictData['vnets'] | ForEach-Object {$_.Location } ) | Select-Object -Unique

foreach ($regionName in $regions) {
    $regionData = $regionTemplate
    $regionData = $regionData.Replace("[id]", $regionName)
    $regionData = $regionData.Replace("[name]", "`"{0}`"" -f $regionName)
    $regionVnets = ''
    $vnets = $dictData['vnets'] | Where-Object { $_.Location -eq $regionName }

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

            $linkedRouteTable = $subnet.properties.routeTable.id

            if ($null -ne $linkedRouteTable) {
                $routeTable = $dictData['routeTables'] | Where-Object { $_.Id -eq $linkedRouteTable }
                $routeTableMarkup = "`t`t`t" + $routeTableTemplate
                $routeTableMarkup = $routeTableMarkup.Replace("[id]", $routeTable.name.Replace("-", ""))
                $routeTableMarkup = $routeTableMarkup.Replace("[name]", "`"{0}`"" -f $routeTable.name)
                $routeTableMarkup = $routeTableMarkup.Replace("[technology]", "`"{0}`"" -f "TBD")
                $routeTableMarkup = $routeTableMarkup.Replace("[description]", "`"{0}`"" -f "demo")
                $subnetServicesMarkup += $routeTableMarkup + "`n"
            }

            $linkedNsg = $subnet.properties.networkSecurityGroup.id

            if ($null -ne $linkedNsg) {
                $nsg = $dictData['nsgs'] | Where-Object { $_.Id -eq $linkedNsg }
                $nsgMarkup = "`t`t`t" + $nsgTemplate
                $nsgMarkup = $nsgMarkup.Replace("[id]", $nsg.name.Replace("-", ""))
                $nsgMarkup = $nsgMarkup.Replace("[name]", "`"{0}`"" -f $nsg.name)
                $nsgMarkup = $nsgMarkup.Replace("[technology]", "`"{0}`"" -f "TBD")
                $nsgMarkup = $nsgMarkup.Replace("[description]", "`"{0}`"" -f "demo")
                $subnetServicesMarkup += $nsgMarkup + "`n"
            }

            $linkedVnetGateway = $dictData["vnetGateways"] | Where-Object { $_.Properties.ipConfigurations[0].properties.subnet.id -eq $subnet.id }

            if ($linkedVnetGateway) {
                $gatewayMarkup = "`t`t`t" + $vnetGatewayTemplate
                $gatewayMarkup = $gatewayMarkup.Replace("[id]", $linkedVnetGateway.name.Replace("-", ""))
                $gatewayMarkup = $gatewayMarkup.Replace("[name]", "`"{0}`"" -f $linkedVnetGateway.name)
                $gatewayMarkup = $gatewayMarkup.Replace("[technology]", "`"SKU: {0}, Capacity: {1}`"" -f $linkedVnetGateway.Properties.sku.name, $linkedVnetGateway.Properties.sku.capacity)
                $gatewayMarkup = $gatewayMarkup.Replace("[description]", "`"{0}`"" -f $linkedVnetGateway.Properties.gatewayType)
                $subnetServicesMarkup += $gatewayMarkup + "`n"
            }

            $linkedFirewall = $dictData["firewalls"] | Where-Object { $_.Properties.ipConfigurations[0].properties.subnet.id -eq $subnet.id }

            if ($linkedFirewall) {
                $firewallMarkup = "`t`t`t" + $firewallTemplate
                $firewallMarkup = $firewallMarkup.Replace("[id]", $linkedFirewall.name.Replace("-", ""))
                $firewallMarkup = $firewallMarkup.Replace("[name]", "`"{0}`"" -f $linkedFirewall.name)
                $firewallMarkup = $firewallMarkup.Replace("[technology]", "`"SKU: {0}`"" -f $linkedFirewall.Properties.sku.tier)
                $firewallMarkup = $firewallMarkup.Replace("[description]", "`"<B>{0}</B>`"" -f $linkedFirewall.Properties.ipConfigurations[0].properties.privateIPAddress )
                $subnetServicesMarkup += $firewallMarkup + "`n"         
            }

            # append markup to subnet
            if ($subnetServicesMarkup) {
                $subnetMarkup += " {`n"
                $subnetMarkup += $subnetServicesMarkup
                $subnetMarkup += "`t`t}`n"
            }

            $subnetMarkupContainer += "`n"
            $subnetMarkupContainer += "`t`t" + $subnetMarkup

            $subnetMarkupIds.Add($subnetMarkupId)
        }

        # append markup for vertical alignment of subnets
        $hiddenLinkMarkup = "`n"

        for ($i=0; $i -lt $subnetMarkupIds.Count; $i++) {
            if ($i -gt 0) {
                $hiddenLinkMarkup += "`t`t{0} -[hidden]d-> {1}`n" -f $subnetMarkupIds[$i-1], $subnetMarkupIds[$i]
            }
        }
        
        $subnetMarkupContainer += $hiddenLinkMarkup

        # insert vnet data
        $vnetMarkup = $vnetMarkup.Replace("[subnets]", $subnetMarkupContainer)
        $regionVnets += "`n"
        $regionVnets += "`t" + $vnetMarkup
    }

    $regionData = $regionData.Replace("[vnets]", $regionVnets)
    $diagramContent += "`n`n"
    $diagramContent += $regionData
}

$dictPeerings = @{}
$vnetPeerings = "`n"
$vnetIds = @( $dictData['vnets'] | ForEach-Object {$_.Name } )

# Peerings
foreach($vnet in $dictData['vnets']) {

    if ($vnet.Properties.virtualNetworkPeerings.Count -gt 0) {

        foreach($peering in $vnet.Properties.virtualNetworkPeerings) {

            $remoteVnetId = $peering.properties.remoteVirtualNetwork.id.Split("/")[8]

            if ($remoteVnetId -in $vnetIds ) {
                
                # check to see if there is already a peering. No need to complicate the diagram with bi-directional peering
                if (! $dictPeerings.ContainsKey($remoteVnetId)) {
                    $peeringMarkup = "{0} -----d- {1}" -f $vnet.Name.Replace("-", ""), $remoteVnetId.Replace("-", "")
                    $vnetPeerings += "`n" + $peeringMarkup
                    $dictPeerings.Add($vnet.Name, $remoteVnetId)
                }

            }
        }

    }
}

$diagramContent += $vnetPeerings

$diagram = $diagram.Replace("[TITLE]", "sample-diagram")
$diagram = $diagram.Replace("[BODY]", $diagramContent)
$diagram | Out-File "network-diag.puml"
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

$diagramContent = ""

$regions = @( $dictData['vnets'] | ForEach-Object {$_.Location } ) | Select-Object -Unique

foreach ($regionName in $regions) {
    $regionData = $regionTemplate
    $regionData = $regionData.Replace("[id]", $regionName)
    $regionData = $regionData.Replace("[name]", "`"{0}`"" -f $regionName)
    $regionVnets = ''
    $vnets = $dictData['vnets'] | Where-Object { $_.Location -eq $regionName }

    foreach ($vnet in $vnets) {
        $vnetData = $vnetTemplate
        $descriptionText = ""

        # DNS settings
        $dnsSettings = $vnet.Properties.dhcpOptions.dnsServers

        if ($dnsSettings.Length -gt 0) {
            foreach ($dnsServer in $dnsSettings) { $descriptionText += $dnsServer + " " }
        } else {
            $descriptionText += "Azure Resolver"
        }

        $vnetData = $vnetData.Replace("[id]", $vnet.Name.Replace("-", ""))
        $vnetData = $vnetData.Replace("[name]", "`"{0}`"" -f $vnet.Name)
        $vnetData = $vnetData.Replace("[technology]", "`"{0}`"" -f $vnet.Properties.addressSpace.addressPrefixes)
        $vnetData = $vnetData.Replace("[description]", "`"DNS: {0}`"" -f $descriptionText)
        $vnetSubnets = ''

        foreach ($subnet in $vnet.Properties.subnets) {
            $subnetData = $subnetTemplate
            $subnetData = $subnetData.Replace("[id]", $subnet.name.Replace("-", ""))
            $subnetData = $subnetData.Replace("[name]", "`"{0}`"" -f $subnet.name)
            $subnetData = $subnetData.Replace("[technology]", "`"{0}`"" -f $subnet.properties.addressPrefix)
            $subnetData = $subnetData.Replace("[description]", "`"{0}`"" -f "demo")

            $subnetServicesMarkup = ""

            # add routeTables
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

            # add nsgs
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

            # add gateways
            $linkedVnetGateway = 

            # append markup to subnet
            if ($subnetServicesMarkup) {
                $subnetData += " {`n"
                $subnetData += $subnetServicesMarkup
                $subnetData += "`t`t}`n"
            }


            $vnetSubnets += "`n"
            $vnetSubnets += "`t`t" + $subnetData
        }

        $vnetData = $vnetData.Replace("[subnets]", $vnetSubnets)
        $regionVnets += "`n"
        $regionVnets += "`t" + $vnetData
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
                    $peeringMarkup = "{0} <---> {1}" -f $vnet.Name.Replace("-", ""), $remoteVnetId.Replace("-", "")
                    $vnetPeerings += "`n" + $peeringMarkup
                    $dictPeerings.Add($vnet.Name, $remoteVnetId)
                }

            }
        }

    }
}

$diagramContent += $vnetPeerings

$diagram = $diagram.Replace("[BODY]", $diagramContent)
$diagram | Out-File "network-diag.puml"
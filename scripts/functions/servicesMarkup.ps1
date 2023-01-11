function Get-RouteTableMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $routeTableTemplate = Get-Content './templates/routeTable.puml' -Raw
    $routeTableMarkup = $routeTableTemplate
    $routeTableMarkup = $routeTableMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $routeTableMarkup = $routeTableMarkup.Replace("[name]", "`"{0}`"" -f $Data.name)
    $routeTableMarkup = $routeTableMarkup.Replace("[technology]", "`"{0}`"" -f "null")
    $routeTableMarkup = $routeTableMarkup.Replace("[description]", "`"{0}`"" -f "demo")
    $routeTableMarkup
}

function Get-NsgMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $nsgTemplate = Get-Content './templates/nsg.puml' -Raw
    $nsgMarkup = $nsgTemplate
    $nsgMarkup = $nsgMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $nsgMarkup = $nsgMarkup.Replace("[name]", "`"{0}`"" -f $Data.name)
    $nsgMarkup = $nsgMarkup.Replace("[technology]", "`"{0}`"" -f "null")
    $nsgMarkup = $nsgMarkup.Replace("[description]", "`"{0}`"" -f "demo")
    $nsgMarkup
}

function Get-VnetGatewayMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $vnetGatewayTemplate = Get-Content './templates/vnetGateway.puml' -Raw
    $gatewayMarkupId = $Data.name.Replace("-", "")
    $gatewayMarkup = "`t`t`t" + $vnetGatewayTemplate
    $gatewayMarkup = $gatewayMarkup.Replace("[id]", $gatewayMarkupId )
    $gatewayMarkup = $gatewayMarkup.Replace("[name]", "`"{0}`"" -f $Data.name)
    $technologyText = "SKU: {0}, Capacity: {1}" -f $Data.Properties.sku.name, $Data.Properties.sku.capacity
    $gatewayMarkup = $gatewayMarkup.Replace("[technology]", "`"{0}`"" -f $technologyText)
    $gatewayMarkup = $gatewayMarkup.Replace("[description]", "`"{0}`"" -f $Data.Properties.gatewayType)
    $gatewayMarkup
}

function Get-FirewallMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $firewallTemplate = Get-Content './templates/firewall.puml' -Raw
    $firewallMarkup = $firewallTemplate
    $firewallMarkup = $firewallMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $firewallMarkup = $firewallMarkup.Replace("[name]", "`"{0}`"" -f $Data.name)
    $firewallMarkup = $firewallMarkup.Replace("[technology]", "`"SKU: {0}`"" -f $Data.Properties.sku.tier)
    $firewallMarkup = $firewallMarkup.Replace("[description]", "`"<B>{0}</B>`"" -f $Data.Properties.ipConfigurations[0].properties.privateIPAddress )
    $firewallMarkup
}

function Get-LoadBalancerMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $loadBalancerTemplate = Get-Content './templates/loadBalancer.puml' -Raw
    $loadBalancerMarkup = $loadBalancerTemplate
    $loadBalancerMarkup = $loadBalancerMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $loadBalancerMarkup = $loadBalancerMarkup.Replace("[name]", "`"{0}`"" -f $Data.Name)
    $loadBalancerMarkup = $loadBalancerMarkup.Replace("[technology]", "`"SKU: {0}`"" -f $Data.Sku.Name)
    $loadBalancerMarkup = $loadBalancerMarkup.Replace("[description]", "`"<B>{0}</B>`"" -f "TBD" )
    $loadBalancerMarkup
}

function Get-ApimMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $apimTemplate = Get-Content './templates/apim.puml' -Raw
    $apimMarkup = $apimTemplate
    $apimMarkup = $apimMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $apimMarkup = $apimMarkup.Replace("[name]", "`"{0}`"" -f $Data.Name)
    $technologyText = "`"SKU: {0}\nInstances: {1}`"" -f $Data.Sku.Name, $Data.Sku.Capacity
    $apimMarkup = $apimMarkup.Replace("[technology]", $technologyText)
    $descriptionText = "`"<B>{0}</B> ({1})`"" -f $Data.Properties.gatewayUrl, $Data.Properties.privateIdAddpresses[0]
    $apimMarkup = $apimMarkup.Replace("[description]", $descriptionText )
    $apimMarkup
}

function Get-DataBricksMarkup {
    param ( [Parameter(Mandatory=$true,Position=0)] $Data,
            [Parameter(Mandatory=$true,Position=1)] $IsPrivateSubnet 
     )
    $adbTemplate = Get-Content './templates/databricks.puml' -Raw
    $adbMarkup = $adbTemplate
    
    if ($IsPrivateSubnet) {
        $adbMarkup = $adbMarkup.Replace("[id]", $Data.name.Replace("-", "") + "private")
        $adbMarkup = $adbMarkup.Replace("[name]", "`"{0} (Private)`"" -f $Data.Name)
    } else {
        $adbMarkup = $adbMarkup.Replace("[id]", $Data.name.Replace("-", "") + "public")
        $adbMarkup = $adbMarkup.Replace("[name]", "`"{0} (Public)`"" -f $Data.Name) 
    }

    # $adbMarkup = $adbMarkup.Replace("[name]", "`"{0}`"" -f $Data.Name)
    $adbMarkup = $adbMarkup.Replace("[technology]", "`"SKU: {0}`"" -f $Data.Sku.Name)
    $adbMarkup = $adbMarkup.Replace("[description]", "null" )
    $adbMarkup
}

function Get-VmssMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $vmssTemplate = Get-Content './templates/vmss.puml' -Raw
    $vmssMarkup = $vmssTemplate
    $vmssMarkup = $vmssMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $vmssMarkup = $vmssMarkup.Replace("[name]", "`"{0}`"" -f $Data.Name)
    $vmssMarkup = $vmssMarkup.Replace("[technology]", "`"SKU: {0}`"" -f $Data.Sku.Name)
    $imagePublisher = $Data.Properties.virtualMachineProfile.storageProfile.imageReference.publisher
    $imageVersion = $Data.Properties.virtualMachineProfile.storageProfile.imageReference.version
    $descriptionMarkup = $imagePublisher + ": " + $imageVersion
    $vmssMarkup = $vmssMarkup.Replace("[description]", "`"{0}`"" -f $descriptionMarkup )
    $vmssMarkup
}
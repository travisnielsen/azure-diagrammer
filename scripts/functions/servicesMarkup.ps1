function Get-VerticalOrientationMarkup {
    param (
        [Parameter(Mandatory=$true)] $MarkupIds,
        [Parameter(Mandatory=$true)] $TabPrefix
    )
    $hiddenLinkMarkup = "`n"
    for ($i=0; $i -lt $MarkupIds.Count; $i++) {
        if ($i -gt 0) {
            $hiddenLinkMarkup += $TabPrefix + "{0} -[hidden]d-> {1}`n" -f $MarkupIds[$i-1], $MarkupIds[$i]
        }
    }
    return $hiddenLinkMarkup
}

function Get-SubscriptionMarkup {
    param (
        [Parameter(Mandatory=$true)] $Subscription,
        [Parameter(Mandatory=$true)] $RegionName
    )

    $subscriptionMarkup = Get-Content './templates/subscription.puml'
    $subscriptionMarkupId = $RegionName + $Subscription.Name.Replace("-", "")
    $subscriptionMarkup = $subscriptionMarkup.Replace("[id]", $subscriptionMarkupId)
    $subscriptionMarkup = $subscriptionMarkup.Replace("[name]", "`"{0}`"" -f $Subscription.Name)
    $subscriptionMarkup = $subscriptionMarkup.Replace("[technology]", "`"NULL`"")
    $subscriptionMarkup = $subscriptionMarkup.Replace("[description]", "`"NULL`"")
    return $subscriptionMarkup
}

function Get-PaasContainerMarkup {
    param (
        [Parameter(Mandatory=$true)] $PaasMarkup,
        [Parameter(Mandatory=$true)] $SubscriptionMarkupId,
        [Parameter(Mandatory=$true)] $VnetMarkupIds
    )

    $paasContainerMarkup = Get-Content './templates/paasContainer.puml' -Raw
    $paasContainerMarkupId = $SubscriptionMarkupId + "PaasContainer"
    $paasContainerMarkup = $paasContainerMarkup.Replace("[paasContainerId]", $paasContainerMarkupId)
    
    # ensure PaaS container is above VNETs in the subscription
    foreach($vnetMarkupId in $VnetMarkupIds) {
        $PaasMarkup += "`n`t$paasContainerMarkupId -[hidden]d-> $vnetMarkupId"
    }

    $paasContainerMarkup = $paasContainerMarkup.Replace("[paasItems]", $PaasMarkup) + "`n"
    return $paasContainerMarkup

}

function Get-RouteTableMarkup {
    param (
        [Parameter(Mandatory=$true)] $Data,
        [Parameter(Mandatory=$true)] $LinkPrefix
    )
    $routeTableTemplate = Get-Content './templates/routeTable.puml' -Raw
    $routeTableMarkup = $routeTableTemplate
    $routeTableMarkup = $routeTableMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $routeTableMarkup = $routeTableMarkup.Replace("[name]", "Custom Routes")
    $routeTableMarkup = $routeTableMarkup.Replace("[technology]", "`"{0}`"" -f "null")
    $serviceLink = $LinkPrefix + $Data.Id + "/routes"
    $routeTableMarkup = $routeTableMarkup.Replace("[description]", "[[${serviceLink} Link]]")
    return $routeTableMarkup
}

function Get-NsgMarkup {
    param (
        [Parameter(Mandatory=$true)] $Data,
        [Parameter(Mandatory=$true)] $LinkPrefix
    )
    $nsgTemplate = Get-Content './templates/nsg.puml' -Raw
    $nsgMarkup = $nsgTemplate
    $nsgMarkup = $nsgMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $nsgMarkup = $nsgMarkup.Replace("[name]", "Network Rules")
    $nsgMarkup = $nsgMarkup.Replace("[technology]", "`"{0}`"" -f "null")
    $serviceLink = $LinkPrefix + $Data.Id + "/overview"
    $nsgMarkup = $nsgMarkup.Replace("[description]", "[[${serviceLink} Link]]")
    return $nsgMarkup
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
    return $gatewayMarkup
}

function Get-FirewallMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $firewallTemplate = Get-Content './templates/firewall.puml' -Raw
    $firewallMarkup = $firewallTemplate
    $firewallMarkup = $firewallMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $firewallMarkup = $firewallMarkup.Replace("[name]", "`"{0}`"" -f $Data.name)
    $firewallMarkup = $firewallMarkup.Replace("[technology]", "`"SKU: {0}`"" -f $Data.Properties.sku.tier)
    $firewallMarkup = $firewallMarkup.Replace("[description]", "`"<B>{0}</B>`"" -f $Data.Properties.ipConfigurations[0].properties.privateIPAddress )
    return $firewallMarkup
}

function Get-LoadBalancerMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $loadBalancerTemplate = Get-Content './templates/loadBalancer.puml' -Raw
    $loadBalancerMarkup = $loadBalancerTemplate
    $loadBalancerMarkup = $loadBalancerMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $loadBalancerMarkup = $loadBalancerMarkup.Replace("[name]", "`"{0}`"" -f $Data.Name)
    $loadBalancerMarkup = $loadBalancerMarkup.Replace("[technology]", "`"SKU: {0}`"" -f $Data.Sku.Name)
    $loadBalancerMarkup = $loadBalancerMarkup.Replace("[description]", "`"<B>{0}</B>`"" -f "TBD" )
    return $loadBalancerMarkup
}

function Get-ApimMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $apimTemplate = Get-Content './templates/apim.puml' -Raw
    $apimMarkup = $apimTemplate
    $apimMarkup = $apimMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $apimMarkup = $apimMarkup.Replace("[name]", "`"{0}`"" -f $Data.Name)
    $technologyText = "`"SKU: {0}\nInstances: {1}`"" -f $Data.Sku.Name, $Data.Sku.Capacity
    $apimMarkup = $apimMarkup.Replace("[technology]", $technologyText)
    $descriptionText = "`"<B>{0}</B> ({1})`"" -f $Data.Properties.gatewayUrl, $Data.Properties.privateIPAddresses[0]
    $apimMarkup = $apimMarkup.Replace("[description]", $descriptionText )
    return $apimMarkup
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
    return $adbMarkup
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
    return $vmssMarkup
}

function Get-AppSvcVnetMarkup {
    param ( [Parameter(Mandatory=$true)] $SubnetMarkupId )
    $serviceTemplate = Get-Content './templates/functionVnetIntegration.puml' -Raw
    $serviceMarkup = $serviceTemplate
    $serviceMarkupId = $SubnetMarkupId + "vnetintegration"
    $serviceMarkup = $serviceMarkup.Replace("[id]", $serviceMarkupId)
    $serviceMarkup = $serviceMarkup.Replace("[name]", "`"{0}`"" -f "VNET Integration")
    $serviceMarkup = $serviceMarkup.Replace("[technology]", "`"{0}`"" -f "null")
    $serviceMarkup = $serviceMarkup.Replace("[description]", "Origin for outbound dependency calls" )
    return $serviceMarkup
}

function Get-PrivateEndpointsMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $serviceMarkup = Get-Content './templates/privateEndpoint.puml' -Raw
    $serviceMarkup = $serviceMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $serviceMarkup = $serviceMarkup.Replace("[name]", "`"{0}`"" -f $Data.Name)
    $serviceMarkup = $serviceMarkup.Replace("[technology]", "`"{0}`"" -f "null")
    $serviceMarkup = $serviceMarkup.Replace("[description]", "Private connection to PaaS service" )
    return $serviceMarkup
}

function Get-RedisVnetMarkup {
    param ( [Parameter(Mandatory=$true)] $Data )
    $serviceMarkup = Get-Content './templates/redis.puml' -Raw
    $serviceMarkup = $serviceMarkup.Replace("[id]", $Data.name.Replace("-", ""))
    $serviceMarkup = $serviceMarkup.Replace("[name]", "`"{0}`"" -f $Data.Name)
    $technologyText = "SKU: " + $Data.Properties.sku.name + ", Capacity: " + $Data.Properties.sku.capacity
    $serviceMarkup = $serviceMarkup.Replace("[technology]", "`"{0}`"" -f $technologyText)
    $serviceMarkup = $serviceMarkup.Replace("[description]", "`"{0}`"" -f $Data.Properties.staticIP)
    return $serviceMarkup
}


function Get-AppServiceMarkup {
    param ( [Parameter(Mandatory=$true,Position=0)] $AppServiceData,
            [Parameter(Mandatory=$true,Position=1)] $ServicePlanData
     )

     $servicePlanItemsMarkup = ""
     $servicePlanIds = @( $ServicePlanData  | ForEach-Object {$_.Id } )
     
     foreach ($servicePlan in $ServicePlanData ) {
        $servicePlanMarkup = Get-Content './templates/appServicePlan.puml' -Raw
        $servicePlanMarkup = $servicePlanMarkup.Replace("[id]", $servicePlan.name.Replace("-", ""))
        $servicePlanMarkup = $servicePlanMarkup.Replace("[name]", "`"{0}`"" -f $servicePlan.Name)
        $skuTier = $servicePlan.Sku.Tier
        $skuName = $servicePlan.Sku.Name
        $workerSize = $servicePlan.Properties.currentWorkerSize
        $currentWorkers = $servicePlan.Properties.currentNumberOfWorkers
        $maxWorkers = $servicePlan.Properties.maximumNumberOfWorkers
        $elasticScaleEnabled = $servicePlan.Properties.elasticScaleEnabled
        $technologyText = "SKU: $skuTier ($skuName), Worker Size: $workerSize)"
        $servicePlanMarkup = $servicePlanMarkup.Replace("[technology]", "`"{0}`"" -f $technologyText)
        $descriptionText = "Capacity: $currentWorkers / $maxWorkers\nElastic Scale: $elasticScaleEnabled"
        $servicePlanMarkup = $servicePlanMarkup.Replace("[description]", "`"{0}`"" -f $descriptionText)

        # add active Function Apps or App Service instances
        
        $appServiceMarkupIds = New-Object -TypeName 'System.Collections.ArrayList'
        $appServiceMarkupItems = ""

        foreach ($appService in $AppServiceData) {
            if ($appService.Properties.serverFarmId -in $servicePlanIds -and $appService.Properties.state -eq "Running") {

                $appServiceMarkup = ""

                if ($appService.kind -eq "functionapp") {
                    $appServiceMarkup = Get-Content './templates/functionApp.puml' -Raw
                } else {
                    $appServiceMarkup = Get-Content './templates/appService.puml' -Raw
                }

                $appServiceMarkupId = $appService.name.Replace("-", "")
                $appServiceMarkupIds.Add($appServiceMarkupId)
                $appServiceMarkup = $appServiceMarkup.Replace("[id]", $appServiceMarkupId)
                $appServiceMarkup = $appServiceMarkup.Replace("[name]", "`"{0}`"" -f $appService.Name)
                $appServiceMarkup = $appServiceMarkup.Replace("[technology]", "`"SKU: {0}`"" -f $appService.Properties.sku)
                $descriptionText = "Min instance count: " + $appService.Properties.siteConfig.minimumElasticInstanceCount
                $appServiceMarkup = $appServiceMarkup.Replace("[description]", "`"{0}`"" -f $descriptionText )

                # if using VNET Integration, append link to subnet
                if ($appService.Properties.virtualNetworkSubnetId) {
                    $subnetMarkupId = $appService.Properties.virtualNetworkSubnetId.Split("/")[10].Replace("-", "") + "vnetintegration"
                    $appServiceLinkMarkup = "`t`t$subnetMarkupId <- $appServiceMarkupId"
                    $appServiceMarkup += "`n" + $appServiceLinkMarkup
                }

                # if configured with Private Endpoint, append link to PE


                # if using Service Endpoint, append link to subnet(s)


                $appServiceMarkupItems += "`n" + $appServiceMarkup
            }
        }

        # append hidden link to force App Service PUML into vertical orientation
        $verticalOrientationMarkup = Get-VerticalOrientationMarkup $appServiceMarkupIds "`t`t"
        $appServiceMarkupItems += "`n" + $verticalOrientationMarkup

        $servicePlanMarkup = $servicePlanMarkup.Replace("[appservices]", "{0}" -f $appServiceMarkupItems)
        $servicePlanItemsMarkup += $servicePlanMarkup
     }

     return $servicePlanItemsMarkup
}

function Get-EventHubMarkup {
    param ( [Parameter(Mandatory=$true,Position=0)] $NamespaceData,
            [Parameter(Mandatory=$true,Position=1)] $ClusterData 
     )
}

function Get-ServiceBusMarkup  {
    param (
        [Parameter(Mandatory=$true,Position=0)] $ServiceBusData,
        [Parameter(Mandatory=$true,Position=1)] $NetworkConfigs,
        [Parameter(Mandatory=$true,Position=2)] $SubnetMarkupIds
    )
    $serviceItemsMarkup = ""

    foreach ($sbNamespace in $ServiceBusData) {

        $serviceMarkup = Get-Content './templates/serviceBus.puml' -Raw
        $serviceMarkupId = $sbNamespace.name.Replace("-", "")
        $serviceMarkup = $serviceMarkup.Replace("[id]", $serviceMarkupId)
        $serviceMarkup = $serviceMarkup.Replace("[name]", "`"{0}`"" -f $sbNamespace.Name)
        $technologyText = "SKU: " + $sbNamespace.Sku.Tier + ", Capacity: " + $sbNamespace.Sku.Capacity + ", Zone Redundancy: " + $sbNamespace.Properties.zoneRedundant
        $serviceMarkup = $serviceMarkup.Replace("[technology]", "`"{0}`"" -f $technologyText)
        $serviceMarkup = $serviceMarkup.Replace("[description]", "`"{0}`"" -f "null")

        # add subnet connections for the instance
        $subscription = $sbNamespace.Id.Split("/")[2]
        $networkConfig = $NetworkConfigs | Where-Object { $_.Id -match $sbNamespace.Id }
        $subnetIds = $networkConfig.VirtualNetworkRules | Where-Object { $_.Subnet.Id -like "*${subscription}*" } | ForEach-Object { $_.Subnet.id } | Select-Object

        $networkRuleLinkMarkup = ""
        foreach ($subnetId in $subnetIds) {
            $subnetMarkupId = $subnetId.Split("/")[10].Replace("-","")
            if ($subnetMarkupId -in $SubnetMarkupIds) {
                $networkRuleLinkMarkup += "`t" + $serviceMarkupId + " <- " + $subnetMarkupId + "`n"
            }
        }
        $serviceMarkup += "`n${networkRuleLinkMarkup}`n"
        $serviceItemsMarkup += $serviceMarkup
    }

    return $serviceItemsMarkup
}

function Get-CosmosDbMarkup  {
    param ( 
        [Parameter(Mandatory=$true,Position=0)] $Data,
        [Parameter(Mandatory=$true,Position=1)] $SubnetMarkupIds
    )

    $serviceItemsMarkup = ""

    foreach ($cosmosInstance in $Data) {

        $serviceMarkup = Get-Content './templates/cosmos.puml' -Raw
        $serviceMarkupId = $cosmosInstance.name.Replace("-", "")
        $serviceMarkup = $serviceMarkup.Replace("[id]", $serviceMarkupId)
        $serviceMarkup = $serviceMarkup.Replace("[name]", "`"{0}`"" -f $cosmosInstance.Name)
        $technologyText = "SKU: " + $cosmosInstance.Properties.databaseAccountOfferType + ", Default consistency level: " + $cosmosInstance.Properties.consistencyPolicy.defaultConsistencyLevel
        $serviceMarkup = $serviceMarkup.Replace("[technology]", "`"{0}`"" -f $technologyText)
        # TODO: Make this dynamic to support accounts with multi-region
        $descriptionText = "Read locations: " + $cosmosInstance.Properties.readLocations[0].locationName + "\nWrite locations: " + $cosmosInstance.Properties.readLocations[0].locationName 
        $serviceMarkup = $serviceMarkup.Replace("[description]", "`"{0}`"" -f $descriptionText)

        # add subnet connections for the instance
        $networkRuleLinkMarkup = ""
        foreach ($subnet in $cosmosInstance.Properties.virtualNetworkRules) {
            $subnetMarkupId = $subnet.id.Split("/")[10].Replace("-","")
            if ($subnetMarkupId -in $SubnetMarkupIds) {
                $networkRuleLinkMarkup += "`t" + $serviceMarkupId + " <- " + $subnetMarkupId + "`n"
            }
        }

        $serviceMarkup += "`n${networkRuleLinkMarkup}`n"
        $serviceItemsMarkup += $serviceMarkup
    }

    return $serviceItemsMarkup
}
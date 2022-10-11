$dictData = @{}
$sourceFiles = Get-ChildItem -Path '..//data'

foreach ($file in $sourceFiles) {
    $dataItems = Get-Content $file.PSPath | ConvertFrom-Json
    $dictData.add( $file.BaseName, $dataItems)
}

$diagram = Get-Content '..//templates/diagram.puml' -Raw
$vnetTemplate = Get-Content '..//templates/vnet.puml' -Raw
$subnetTemplate = Get-Content '..//templates/subnet.puml' -Raw

$diagramContent = ""

# load VNETS
foreach ($vnet in $dictData['vnets']) {
    $vnetData = $vnetTemplate
    $vnetData = $vnetData.Replace("[id]", $vnet.Name.Replace("-", ""))
    $vnetData = $vnetData.Replace("[name]", "`"{0}`"" -f $vnet.Name)
    $vnetData = $vnetData.Replace("[technology]", "`"{0}`"" -f $vnet.Properties.addressSpace.addressPrefixes)
    $vnetData = $vnetData.Replace("[description]", "`"{0}`"" -f "demo")
    $vnetSubnets = ''

    foreach ($subnet in $vnet.Properties.subnets) {
        $subnetData = $subnetTemplate
        $subnetData = $subnetData.Replace("[id]", $subnet.name.Replace("-", ""))
        $subnetData = $subnetData.Replace("[name]", "`"{0}`"" -f $subnet.name)
        $subnetData = $subnetData.Replace("[technology]", "`"{0}`"" -f $subnet.properties.addressPrefix)
        $subnetData = $subnetData.Replace("[description]", "`"{0}`"" -f "demo")
        $vnetSubnets += "`n"
        $vnetSubnets += "`t" + $subnetData
    }

    $vnetData = $vnetData.Replace("[subnets]", $vnetSubnets)
    $diagramContent += "`n`n"
    $diagramContent += $vnetData
}

$diagram = $diagram.Replace("[BODY]", $diagramContent)
$diagram | Out-File "network-diag.puml"
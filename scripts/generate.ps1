$dictData = @{}
$sourceFiles = Get-ChildItem -Path '..//data'

foreach ($file in $sourceFiles) {
    $dataItems = Get-Content $file.PSPath | ConvertFrom-Json
    $dictData.add( $file.BaseName, $dataItems)
}

$diagram = Get-Content '..//templates/diagram.puml'
$vnetTemplate = Get-Content '..//templates/vnet.puml'
$subnetTemplate = Get-Content '..//templates/subnet.puml'

# load VNETS
foreach ($vnet in $dictData['vnets']) {
    $vnetData = $vnetTemplate
    $subnetData = $subnetTemplate
    $vnetData.Replace('[id]', $vnet.Name)
    $vnetData.Replace('[name]', $vnet.Name)
    $vnetData.Replace('[technology]', $vnet.addressSpace.addressPrefixes)

    foreach ($subnet in $vnet.subnets) {


    }

    $vnetData.Replace('[subnets]', $subnetData)
}

$diagram.Replace('[BODY]', $vnetData)

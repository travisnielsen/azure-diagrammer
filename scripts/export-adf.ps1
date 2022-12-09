# Connect-AzAccount -Tenant "TENANT_ID"

# load subscription and tenant IDs
$contextInfo = Get-Content ./config-adf.json | ConvertFrom-Json
Set-AzContext -Subscription $contextInfo.subscriptions[0]
$outFolder = "..//data/" + $contextInfo.subscriptions[0]


$dataFactories = Get-AzDataFactoryV2

foreach ($dataFactory in $dataFactories) {
    $linkedServices = Get-AzDataFactoryV2LinkedService -DataFactoryName $dataFactory.DataFactoryName
    $dataSets = Get-AzDataFactoryV2Dataset -DataFactoryName $dataFactory.DataFactoryName
    $integrationRuntimes = Get-AzDataFactoryV2IntegrationRuntime -DataFactoryName $dataFactory.DataFactoryName
    $pipelines = Get-AzDataFactoryV2Pipeline -DataFactoryName $dataFactory.DataFactoryName
    $dataFlows = Get-AzDataFactoryV2DataFlow -DataFactoryName $dataFactory.DataFactoryName
}
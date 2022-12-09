# Connect-AzAccount -Tenant "TENANT_ID"

# load subscription and tenant IDs
$contextInfo = Get-Content ./config-adf.json | ConvertFrom-Json
Set-AzContext -Subscription $contextInfo.subscriptions[0]
$outFolder = "..//data/" + $contextInfo.subscriptions[0]

$listDataFactories = Get-AzDataFactoryV2
$listLinkedServices = New-Object -TypeName 'System.Collections.ArrayList'
$listDataSets = New-Object -TypeName 'System.Collections.ArrayList'
$listIntegrationRuntimes = New-Object -TypeName 'System.Collections.ArrayList'
$listPipelines = New-Object -TypeName 'System.Collections.ArrayList'
$listDataFlows = New-Object -TypeName 'System.Collections.ArrayList'

foreach ($dataFactory in $listDataFactories) {
    Get-AzDataFactoryV2LinkedService -DataFactoryName $dataFactory.DataFactoryName -ResourceGroupName $dataFactory.ResourceGroupName | ForEach-Object { $listLinkedServices.Add($_) }
    Get-AzDataFactoryV2Dataset -DataFactoryName $dataFactory.DataFactoryName -ResourceGroupName $dataFactory.ResourceGroupName | ForEach-Object { $listDataSets.Add($_) }
    Get-AzDataFactoryV2IntegrationRuntime -DataFactoryName $dataFactory.DataFactoryName -ResourceGroupName $dataFactory.ResourceGroupName | ForEach-Object { $listIntegrationRuntimes.Add($_) }
    Get-AzDataFactoryV2Pipeline -DataFactoryName $dataFactory.DataFactoryName -ResourceGroupName $dataFactory.ResourceGroupName | ForEach-Object { $listPipelines.Add($_) }
    Get-AzDataFactoryV2DataFlow -DataFactoryName $dataFactory.DataFactoryName -ResourceGroupName $dataFactory.ResourceGroupName | ForEach-Object { $listDataFlows.Add($_) }
}

New-Item -Path "${outFolder}" -ItemType Directory
ConvertTo-Json -InputObject $listDataFactories -Depth 7 | Out-File "${outFolder}/dataFactories.json"
ConvertTo-Json -InputObject $listLinkedServices -Depth 7 | Out-File "${outFolder}/linkedServices.json"
ConvertTo-Json -InputObject $listDataSets -Depth 7 | Out-File "${outFolder}/dataSets.json"
ConvertTo-Json -InputObject $listIntegrationRuntimes -Depth 7 | Out-File "${outFolder}/integrationRuntimes.json"
ConvertTo-Json -InputObject $listPipelines -Depth 7 | Out-File "${outFolder}/pipelines.json"
ConvertTo-Json -InputObject $listDataFlows -Depth 7 | Out-File "${outFolder}/dataFlows.json"
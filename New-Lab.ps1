# Create Lab resource group and deployment
. .\Variables.ps1
Connect-AzureRmAccount
New-AzureRmResourceGroup -Name $Lab -Location $Region
New-AzureRmResourceGroupDeployment -Name lab-resources -ResourceGroupName $Lab -TemplateFile .\infrastructure\arm-template.json

# Create Lab User, Role, and Policy applied to the Lab resource group
. .\Helpers.ps1
$PolicyComponents = Get-LabPolicyComponents
$ResourceGroupScope = Get-AzureRmResourceGroup -Name $Lab

Connect-AzureAD
$LabUser = New-LabUser $User $Pass

Add-CustomRoleField $RoleDefinitionName $PolicyComponents $ResourceGroupScope
$CustomRoleFile = Write-TempCustomRole $PolicyComponents['Role']
$RoleDefinition = New-AzureRmRoleDefinition -InputFile $CustomRoleFile
$RoleAssignment = New-AzureRmRoleAssignment -SignInName $User -ResourceGroupName $Lab -RoleDefinitionName $RoleDefinitionName

$Definition = New-AzureRmPolicyDefinition -Name $PolicyDefinitionName -DisplayName 'Lab Policy' `
                -description 'Lab policy' `
                -Metadata '{"Category":"Lab"}' `
                -Policy $PolicyComponents['Policy'] `
                -Parameter $PolicyComponents['Parameters'] `
                -Mode All
$Assignment = New-AzureRmPolicyAssignment -Name $PolicyAssignmentName -DisplayName 'Lab Policy Assignment' `
                -Scope $ResourceGroupScope.ResourceId `
                -PolicyDefinition $Definition `
                -PolicyParameter $PolicyComponents['Values']
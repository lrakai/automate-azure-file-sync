function New-LabUser {
    param (
        [String]$User, [String]$Password
    )
    $PasswordProfile = New-Object -TypeName Microsoft.Open.AzureAD.Model.PasswordProfile
    $PasswordProfile.Password = $Password
    $PasswordProfile.EnforceChangePasswordPolicy = $false
    $PasswordProfile.ForceChangePasswordNextLogin = $false
    New-AzureADUser -DisplayName $User.Split('@')[0] -PasswordProfile $PasswordProfile -UserPrincipalName $User -AccountEnabled $true -MailNickName "Newuser"
}

function Get-LabPolicyComponents {
    $file = ".\infrastructure\policy.json"
    $text = [IO.File]::ReadAllText($file)
    $parser = New-Object Web.Script.Serialization.JavaScriptSerializer
    $parser.MaxJsonLength = $text.length
    $policy = $parser.Deserialize($text, @{}.GetType())
    return @{
        Policy      = $parser.Serialize($policy['policyRule'])
        Permissions = $parser.Serialize($policy['permissions'])
        Parameters  = $parser.Serialize($policy['parameters'])
        Values      = $parser.Serialize($policy['parameters_values'])
    }
}

function Add-CustomRoleField {
    param (
        $RoleDefinitionName,
        $PolicyComponents,
        $ResourceGroupScope
    )
    $parser = New-Object Web.Script.Serialization.JavaScriptSerializer
    $parser.MaxJsonLength = $PolicyComponents['Permissions'].length+1024
    $role = $parser.Deserialize($PolicyComponents['Permissions'], @().GetType())[0]
    $role['Name'] = $RoleDefinitionName
    $role['Description'] = 'Lab Role'
    $role['AssignableScopes'] = @($ResourceGroupScope.ResourceId)
    $PolicyComponents['Role'] = $parser.Serialize($role)
}

function Write-TempCustomRole {
    param (
        $Permissions
    )
    $CustomRoleFile = [System.IO.Path]::GetTempFileName()
    $stream = [System.IO.StreamWriter] $CustomRoleFile
    $stream.WriteLine($Permissions)
    $stream.close()
    $CustomRoleFile
}

# Create Lab resource group and deployment
. .\Variables.ps1
Connect-AzureRmAccount
New-AzureRmResourceGroup -Name $Lab -Location $Region
New-AzureRmResourceGroupDeployment -Name lab-resources -ResourceGroupName $Lab -TemplateFile .\infrastructure\arm-template.json

# Create Lab User, Role, and Policy applied to the Lab resource group
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
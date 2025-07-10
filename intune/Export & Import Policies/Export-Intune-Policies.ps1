#check for log directory and start transcript 
$workingPath = "C:\Temp\IntuneExport"
Write-Host -ForegroundColor DarkYellow "Checking for directory $workingPath for transcript and output files"
If (!(Test-Path $workingPath)) {
	New-Item -Path $workingPath -ItemType Directory
}
$LogPath = "$workingPath\log"
New-Item -Path $LogPath -ItemType Directory -Force
Start-Transcript -Path $LogPath\PolicyExport.log -Force

#check for and install required modules
$modules = 'Microsoft.Graph.Authentication'

Write-Host -ForegroundColor DarkYellow "Installing Required Modules if they're missing..."
Foreach ($module in $modules) {
if (Get-Module -ListAvailable -Name $module) {
    Write-Host -ForegroundColor Yellow "$module module is already installed"
} 
else {
    Write-Host -ForegroundColor Yellow "Installing the $module Module for Current User"
    Install-Module -Name $module -Scope CurrentUser -Force 
    Write-Host "Installed $module module for current user"
}
}

$invalidChars = [System.IO.Path]::GetInvalidFileNameChars()

Connect-MgGraph -Scopes "Policy.Read.All","DeviceManagementConfiguration.Read.All"

#Conditional Access Policies
$path = "$workingPath\CA-Policies"
New-Item -Path $path -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting Conditional Access Policies to $path"
$uri = "https://graph.microsoft.com/beta/identity/conditionalAccess/policies/"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$policyIds = $response.value.id
Foreach ($policyId in $PolicyIds) {
$policy = Invoke-MgGraphRequest -Method GET -URI $uri$policyId
$policyjson = $policy | ConvertTo-Json -Depth 15
$name = -join ($policy.displayname.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
$policyJson | Out-File -LiteralPath "$path\$name.json" -Encoding utf8
write-host -ForegroundColor yellow "Exported $($policy.displayname)successfully"
}

#Named Locations
$path = "$workingPath\Named Locations"
New-Item -Path $path -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting Named Locations to $path"
$uri = "https://graph.microsoft.com/beta/conditionalAccess/namedLocations/"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$policyIds = $response.value.id
Foreach ($policyId in $PolicyIds) {
$policy = Invoke-MgGraphRequest -Method GET -URI $uri$policyId -OutputType PSObject
$policy.PsObject.Properties.Remove("id")
$policy.PsObject.Properties.Remove("ModifiedDateTime")
$policy.PsObject.Properties.Remove("createdDateTime")
$policyjson = $policy | ConvertTo-Json -Depth 15
$name = -join ($policy.displayname.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
$policyJson | Out-File -LiteralPath "$path\$name.json" -Encoding utf8
write-host -ForegroundColor yellow "Exported $($policy.displayname) successfully"
}

#Settings Catalog Policies
$path = "$workingPath\ConfigurationPolicies"
New-Item -Path $path -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting Configuration Policies to $path"
$uri = "https://graph.microsoft.com/beta/deviceManagement/configurationPolicies/"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$allPolicies = @()
do {
    $allPolicies += $response.value
    $nextLink = $response.'@odata.nextLink'
    if ($nextLink) {
        $response = Invoke-MgGraphRequest -Method GET -Uri $nextLink
    }
} while ($nextLink)
Foreach ($policy in $allPolicies) {
    $name = -join ($policy.name.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
    $id = $policy.id
    $policy = Invoke-MgGraphRequest -Method GET -Uri $uri/$id -OutputType PSObject
    $policyconfig = Invoke-MgGraphRequest -Method GET -Uri "$uri$($policy.id)/settings"
    $policy | Add-Member -MemberType NoteProperty -Name 'settings' -Value @() -Force
    $policy.settings += $policyconfig.value
    $policyJson = $policy | ConvertTo-Json -Depth 25 
    $policyJson | Out-File -LiteralPath "$path\$name.json" -Encoding utf8
    Write-Host -ForegroundColor Yellow "Exported $($policy.name) successfully"
}

#App Protection Policies
$path = "$workingPath\App_Protection_Policies"
New-Item -Path $path -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting App Protection Policies to $path"
$uri = "https://graph.microsoft.com/beta/deviceAppManagement/managedAppPolicies/"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$policyIds = $response.value.id
Foreach ($policyId in $PolicyIds) {
$policy = Invoke-MgGraphRequest -Method GET -URI $uri$policyId
$policyjson = $policy | ConvertTo-Json -Depth 15
$name = -join ($policy.displayname.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
$policyJson | Out-File -LiteralPath "$path\$name.json" -Encoding utf8
write-host -ForegroundColor yellow "Exported $($policy.displayname) successfully"
}

#App Configuration Policies
$path = "$workingPath\App_Configuration_Policies"
New-Item -Path $path -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting App Configuration Policies to $path"
$uri = "https://graph.microsoft.com/beta/deviceAppManagement/mobileAppConfigurations/"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$policyIds = $response.value.id
Foreach ($policyId in $PolicyIds) {
$policy = Invoke-MgGraphRequest -Method GET -URI $uri$policyId
$policyjson = $policy | ConvertTo-Json -Depth 15
$name = -join ($policy.displayname.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
$policyJson | Out-File -LiteralPath "$path\$name.json" -Encoding utf8
write-host -ForegroundColor yellow "Exported $($policy.displayname) successfully"
}

#Custom Device Configuration Profiles
$path = "$workingPath\DeviceConfigurations"
New-Item -Path $path -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting Device Configurations to $path"
$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceConfigurations/"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$policyIds = $response.value.id
Foreach ($policyId in $PolicyIds) {
$uridecrypted = "?includeEncryptedData=true"
$policy = Invoke-MgGraphRequest -Method GET -URI "$uri$policyId$uridecrypted" -OutputType PSObject
if ($policy.'@odata.type' -eq "#microsoft.graph.windows10CustomConfiguration") {
    Foreach ($omaSetting in $policy.omaSettings) {
        if ($omaSetting.isEncrypted -eq $true) {
        $plainTextUri = "$uri$policyId/getOmaSettingPlainTextValue(secretReferenceValueId='$($omaSetting.secretReferenceValueId)')"
        $plainTextValue = Invoke-MgGraphRequest -Method GET -Uri $plainTextUri
        $omasetting.value = $plainTextValue.value
        $policy.PsObject.Properties.Remove("id")
        $policy.PsObject.Properties.Remove("lastModifiedDateTime")
        $omaSetting.PsObject.Properties.Remove("secretReferenceValueId")
        $omaSetting.PsObject.Properties.Remove("isEncrypted")
        }
        else {
        $policy.PsObject.Properties.Remove("id")
        $policy.PsObject.Properties.Remove("lastModifiedDateTime")
        $omaSetting.PsObject.Properties.Remove("secretReferenceValueId")
        $omaSetting.PsObject.Properties.Remove("isEncrypted")
        $omaSetting.PsObject.Properties.Remove("isReadOnly")
        }
    }
}
$policyjson = $policy | ConvertTo-Json -Depth 15
$name = -join ($policy.displayname.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
$policyJson | Out-File -LiteralPath "$path\$name.json" -Encoding utf8
write-host -ForegroundColor yellow "Exported $($policy.displayname) successfully"
}

#Remediations
$path = "$workingPath\temp\Remediations"
New-Item -Path $path -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting App Configuration Policies to $path"
$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceHealthScripts/"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$policyIds = $response.value.id
Foreach ($policyId in $PolicyIds) {
$policy = Invoke-MgGraphRequest -Method GET -URI $uri$policyId -OutputType PSObject
$policy.PsObject.Properties.Remove("id")
$policy.PsObject.Properties.Remove("lastModifiedDateTime")
$policyjson = $policy | ConvertTo-Json -Depth 15
$name = -join ($policy.displayname.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
$policyJson | Out-File -LiteralPath "$path\$name.json" -Encoding utf8
write-host -ForegroundColor yellow "Exported $($policy.displayname) successfully"
}

#Windows Platform Scripts
$path = "$workingPath\temp\PowerShell_Scripts"
New-Item -Path $path -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting Windows PowerShell scripts to $path"
$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceManagementScripts/"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$policyIds = $response.value.id
Foreach ($policyId in $PolicyIds) {
$policy = Invoke-MgGraphRequest -Method GET -URI $uri$policyId -OutputType PSObject
$policy.PsObject.Properties.Remove("id")
$policy.PsObject.Properties.Remove("lastModifiedDateTime")
$policyjson = $policy | ConvertTo-Json -Depth 15
$name = -join ($policy.displayname.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
$policyJson | Out-File -LiteralPath "$path\$name.json" -Encoding utf8
write-host -ForegroundColor yellow "Exported $($policy.displayname) successfully"
}

#Filters
$path = "$workingPath\temp\Filters"
New-Item -Path $path -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting Filters to $path"
$uri = "https://graph.microsoft.com/beta/deviceManagement/assignmentFilters/"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$policyIds = $response.value.id
Foreach ($policyId in $PolicyIds) {
$policy = Invoke-MgGraphRequest -Method GET -URI $uri$policyId -OutputType PSObject
$policy.PsObject.Properties.Remove("id")
$policy.PsObject.Properties.Remove("lastModifiedDateTime")
$policy.PsObject.Properties.Remove("createdDateTime")
$policy.PsObject.Properties.Remove("payloads")
$policyjson = $policy | ConvertTo-Json -Depth 15
$name = -join ($policy.displayname.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
$policyJson | Out-File -LiteralPath "$path\$name.json" -Encoding utf8
write-host -ForegroundColor yellow "Exported $($policy.displayname) successfully"
}

### Custom Compliance Scripts
$path = "$workingPath\temp\custom_compliance_scripts"
New-Item -Path $path -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting Compliance Policies to $path"
$URI = "https://graph.microsoft.com/beta/deviceManagement/deviceComplianceScripts/"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$policyIds = $response.value.id
$ComplianceScriptReference = @()
Foreach ($policyId in $PolicyIds) {
$policy = Invoke-MgGraphRequest -Method GET -URI "$uri$policyId" -OutputType PSObject
$name = -join ($policy.displayname.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
$ComplianceScriptReference += [PSCustomObject]@{
    ID = $policyId
    DisplayName = $policy.displayname
    CompliancePolicyName = $null
    NewCompliancePolicyID = $null
}
$policy.PsObject.Properties.Remove("id")
$policy.PsObject.Properties.Remove("lastModifiedDateTime")
$policy.PsObject.Properties.Remove("createdDateTime")
$policyjson = $policy | ConvertTo-Json -Depth 15
$policyJson | Out-File -LiteralPath "$path\$name.json" -Encoding utf8
write-host -ForegroundColor yellow "Exported $($policy.displayname) successfully"
}

#Compliance Policies
$compliancepolicypath = "$workingPath\temp\compliance_policies"
New-Item -Path $compliancepolicypath -ItemType Directory -Force
Write-Host -ForegroundColor Green "Exporting Compliance Policies to $compliancepolicypath"
$uri = "https://graph.microsoft.com/beta/deviceManagement/deviceCompliancePolicies/"
$scheduledActionsConfig = "?`$expand=scheduledActionsForRule(`$expand=scheduledActionConfigurations)"
$response = Invoke-MgGraphRequest -Method GET -Uri $uri
$policyIds = $response.value.id
$allPolicies = @()
Foreach ($policyId in $PolicyIds) {
$policy = Invoke-MgGraphRequest -Method GET -URI "$uri$policyId$scheduledActionsConfig" -OutputType PSObject
$policy.PsObject.Properties.Remove("id")
$policy.PsObject.Properties.Remove("lastModifiedDateTime")
$policy.PsObject.Properties.Remove("createdDateTime")
$policy.PsObject.Properties.Remove("scheduledActionsForRule@odata.context")
($policy.scheduledActionsForRule[0]).PSObject.Properties.Remove('scheduledActionConfigurations@odata.context')
$policy.scheduledActionsForRule[0].ruleName = "ComplianceRule"
$policyjson = $policy | ConvertTo-Json -Depth 15
$name = -join ($policy.displayname.ToCharArray() | Where-Object { $invalidChars -notcontains $_ })
$policyJson | Out-File -LiteralPath "$compliancepolicypath\$name.json" -Encoding utf8
write-host -ForegroundColor yellow "Exported $($policy.displayname) successfully"
$allPolicies += $policy
}

ForEach ($policy in $allPolicies) {
    $compliancescriptid = $policy.deviceCompliancePolicyScript.deviceComplianceScriptId
    If ($compliancescriptid) {
        $matchingscript = $ComplianceScriptReference | Where-Object { $_.ID -eq $compliancescriptid }
        If ($matchingscript) {
            Write-Host "Found compliance scrpit match for $($policy.displayName)"
            $matchingscript.CompliancePolicyName = $policy.displayName
        }
    }
}
$ComplianceScriptReference | export-csv -Encoding utf8 -path $compliancepolicypath\ComplianceScriptReference.csv

Stop-Transcript
Disconnect-MgGraph

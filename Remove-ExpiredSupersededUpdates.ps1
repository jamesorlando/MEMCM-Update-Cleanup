<#
.SYNOPSIS
    Perform a cleanup of expired or superseded updates that are deployed
.PARAMETER SiteCode
    SCCM 3 digit site code. Mandatory parameter that must be 3 digits
.PARAMETER ProviderMachineName
    Server where the SMS Provider is located. If not specified a WMI search will be done in an attempt to locate it
.EXAMPLE
    Remove-ExpiredSupersededUpdates -SiteCode JPO -ProviderMachineName "cm01.contoso.com"
.NOTES
    Due to parameter validation, do not use single or double quotes for site code. Example: -SiteCode "JPO" will not work

    Script name: Remove-ExpiredSupersededUpdates
    Author: James Orlando
    Contact: James.Orlando@microsoft.com
    Date Created: 11-20-2019
    Date Modified: 11-20-2019
#>

#Parameters
Param(
[Parameter(Mandatory)]
[ValidateLength(3,3)]
[string]$SiteCode,
[Parameter(Mandatory=$false)]
[string]$ProviderMachineName
)

Function Write-Log ($log)
{
    $log + " " + (Get-Date) | Out-File "$env:SMS_LOG_PATH\Remove-ExpiredSupersededUpdates.log" -Append
    if((Get-Item "$env:SMS_LOG_PATH\Remove-ExpiredSupersededUpdates.log").lenght -gt "5mb")
        {
        Rename-Item "$env:SMS_LOG_PATH\Remove-ExpiredSupersededUpdates.log" -NewName "$env:SMS_LOG_PATH\Remove-ExpiredSupersededUpdates.lo_"
        }
}

#Get SMS Provider location if not declared as a parameter
if($ProviderMachineName -eq $null){
$ProviderMachineName = (Get-WmiObject -Class SMS_ProviderLocation -Namespace root\SMS).machine
}
#imports SCCM Module if needed
if((Get-Module ConfigurationManager) -eq $null) {
    Import-Module "$($ENV:SMS_ADMIN_UI_PATH)\..\ConfigurationManager.psd1"
}
#Create PSDrive for Site
if((Get-PSDrive -Name $SiteCode -PSProvider CMSite -ErrorAction SilentlyContinue) -eq $null) {
    New-PSDrive -Name $SiteCode -PSProvider CMSite -Root $ProviderMachineName }
#Set Location to SMS Site
Set-Location "$($SiteCode):\"

Write-Log -log "Remove-ExpiredSupersededUpdates Started"

#Get Updates that are deployed and superseded or expired
$Updates = Get-CMSoftwareUpdate -fast | Where-Object {$_.IsDeployed -eq $true -and ($_.IsExpired -eq $true -or $_.IsSuperseded -eq $True)}
Write-Log -log ("Found " + $updates.count + " updates that need to be removed from deployments") 

foreach($Update in $Updates)
{
$UpdateGroups = Get-CMSoftwareUpdateGroup | Where-Object {$_.updates -contains $update.CI_ID}
    ForEach($UpdateGroup in $UpdateGroups)
        {
        Remove-CMSoftwareUpdateFromGroup -SoftwareUpdateId $Update.CI_ID -SoftwareUpdateGroupId $UpdateGroup.CI_ID -Force
        Write-Log -log ("Removed " + $Update.LocalizedDisplayName + " from " + $UpdateGroup.LocalizedDisplayName + " Conditions - IsSuperseded: "`
         + $Update.IsSuperseded + " -IsExpired: " + $Update.IsExpired)
        }
}

Write-Log -log "Remove-ExpiredSupersededUpdates Complete"
<#
.SYNOPSIS
    Perform a cleanup of expired, superseded or not required (0) updates that are deployed. To prevent removing updates prior to deployment of new updates use the delay paramenter. For instance
    if updates are deployed 3 days after Patch Tuesday you would not want to stop deploying the updates that are superseded until you are ready to deploy the updates that superseded them. 
.PARAMETER SiteCode
    SCCM 3 digit site code. Mandatory parameter that must be 3 digits
.PARAMETER ProviderMachineName
    Server where the SMS Provider is located. If not specified a WMI search will be done in an attempt to locate it
.EXAMPLE
    Cleanup-UpdateDeployments -SiteCode JPO -ProviderMachineName "cm01.contoso.com" -Delay 3
.NOTES
    Due to parameter validation, do not use single or double quotes for site code. Example: -SiteCode "JPO" will not work
    Script name: Cleanup-UpdateDeployments
    Author: James Orlando
    Contact: James.Orlando@microsoft.com
    Date Created: 11-20-2019
    Date Modified: 04-23-2020
    4-23-2020 Added delay to account for delta between patch tuesday and when customer deployes patches. 
    12-7-2020 Package and SUG Cleanup added
    2/1/2021 Change to break IE 11 logging loop. Get-Unique set to prevent IE 11 update from showing up multiple times. 
    2/4/2021 Typo preventinig log from rolling over. (.length not .lenght)
#>

#Parameters
Param(
[Parameter(Mandatory)]
[ValidateLength(3,3)]
[string]$SiteCode,
[Parameter(Mandatory=$false)]
[string]$ProviderMachineName,
[Parameter(Mandatory=$True)]
[int]$Delay 
)

Function Write-Log ($log)
{
    $log + " " + (Get-Date) | Out-File "$env:SMS_LOG_PATH\CleanupUpdateDeployments.log" -Append
    if((Get-Item "$env:SMS_LOG_PATH\CleanupUpdateDeployments.log").length -gt "5mb")
        {
        Remove-Item "$env:SMS_LOG_PATH\CleanupUpdateDeployments.lo_"
        Rename-Item "$env:SMS_LOG_PATH\CleanupUpdateDeployments.log" -NewName "CleanupUpdateDeployments.lo_" 
        }
}

Function Get-PatchTuesday
    {
        $FirstDay = (Get-Date).AddDays(-((Get-Date).AddDays(-1)).Day) 
        Switch ($FirstDay.DayOfWeek)
        {
            "Monday" {$global:PatchTuesday = $FirstDay.AddDays(8)}
            "Tuesday" {$global:PatchTuesday = $FirstDay.AddDays(7)}
            "Wednesday" {$global:PatchTuesday = $FirstDay.AddDays(13)}
            "Thursday" {$global:PatchTuesday = $FirstDay.AddDays(12)}
            "Friday" {$global:PatchTuesday = $FirstDay.AddDays(11)}
            "Saturday" {$global:PatchTuesday = $FirstDay.AddDays(10)}
            "Sunday" {$global:PatchTuesday = $FirstDay.AddDays(9)}
        }
        Write-Log -log " Patch Tuesday this month is $PatchTuesday"
    }

#Run First Function to establish Patch Tuesday for the month. 
Get-PatchTuesday

If($PatchTuesday.date -lt ((Get-Date).AddDays(-$Delay)).Date -or $PatchTuesday.Date -gt (Get-Date).Date)
    {
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

        Write-Log -log "Cleanup-UpdateDeployments Started"
        Write-Log -log "Cleanup delay specified as $delay days"

        #Get Updates that are deployed and superseded or expired
        $Updates = Get-CMSoftwareUpdate -fast | Where-Object {$_.IsDeployed -eq $true -and ($_.IsExpired -eq $true -or $_.IsSuperseded -eq $True -or $_.NumMissing -eq 0)}
        Write-Log -log ("Found " + $updates.count + " updates that need to be removed from deployments") 

        foreach($Update in $Updates)
            {
            $UpdateGroups = Get-CMSoftwareUpdateGroup | Where-Object {$_.updates -contains $update.CI_ID}
                ForEach($UpdateGroup in $UpdateGroups)
                    {
                    Remove-CMSoftwareUpdateFromGroup -SoftwareUpdateId $Update.CI_ID -SoftwareUpdateGroupId $UpdateGroup.CI_ID -Force
                    Write-Log -log ("Removed " + $Update.LocalizedDisplayName + " from " + $UpdateGroup.LocalizedDisplayName + " Conditions - IsSuperseded: "`
                     + $Update.IsSuperseded + " -IsExpired: " + $Update.IsExpired + " -NumberMissing: " + $Update.NumMissing)
                    }
            }
    
        #Get Sofwate Update Groups with no updates
        $SUGs = Get-CMSoftwareUpdateGroup | ? {$_.NumberOfUpdates -eq 0}
        ForEach($SUG in $Sugs){
            Write-Log -log "Software Update Group $($SUG.LocalizedDisplayName) has $($SUG.NumberOfUpdates), so it will be removed"
            $SUG | Remove-CMSoftwareUpdateGroup -Force
            }

        #Remove Updates from Deployment Packages
        Write-Log -log "Starting Software Update Deployment Package Cleanup"
        $SUDPQuery = "SELECT 
        SMS_PackageToContent.PackageID,
        SMS_CIToContent.ContentID,
        SMS_PackageToContent.ContentSubFolder,
        SMS_SoftwareUpdate.CI_ID
        FROM
        SMS_SoftwareUpdate
        JOIN
        SMS_CIToContent on SMS_CIToContent.CI_ID = SMS_SoftwareUpdate.CI_ID
        JOIN
        SMS_PackageToContent on SMS_PackageToContent.ContentID = SMS_CIToContent.ContentID
        WHERE 
        (SMS_SoftwareUpdate.IsContentProvisioned=1 and SMS_SoftwareUpdate.IsDeployed=0) and SMS_PackageToContent.PackageType = 5"   

        $SUDPData = Get-WmiObject -Namespace "root\SMS\site_$SiteCode" -Query $SUDPQuery 
        $PackageIDs = $SUDPData.SMS_PackageToContent.PackageID | Get-Unique
        Write-Log -log "Found $($PackageIDs.Count) package that needs updates removed and content cleaned. "

        IF ($SUDPData)
        {
           
            Foreach ($PackageID in $PackageIDs) 
            {
                Write-Log -log "Starting cleanup of $($packageid). "
                $GLOBAL:RemoveContentIDs = @()
                $GLOBAL:RemoveSubfolders = @()
                $GLOBAL:RemoveItems = @()

                $GLOBAL:PkgSource = Get-WmiObject -Namespace "root\SMS\site_$SiteCode" -Query  "Select * from SMS_SoftwareUpdatesPackage WHERE PackageID=`"$PackageID`""
                                            
                Foreach ($Object in ($SUDPData))
                {
                    IF ($Object.SMS_PackageToContent.PackageID -eq $PackageID)
                    {
                    
                        $GLOBAL:RemoveContentIDs += $Object.SMS_CIToContent.ContentID

                        $GLOBAL:RemoveSubfolders += $Object.SMS_PackageToContent.ContentSubFolder
                    
                        $RemovePath = $GLOBAL:PkgSource.PkgSourcePath +"\"+ $Object.SMS_PackageToContent.ContentSubFolder

                        $GLOBAL:RemoveItems += $RemovePath
                    }
                }

                Foreach ($Item in $GLOBAL:RemoveItems)
                {
                    Write-Log -log "Deleting update content $($Item)."
                    Remove-Item -LiteralPath filesystem::$Item -Recurse -Force 
                }

                $DeploymentPackage = [wmi]$GLOBAL:PkgSource.__PATH
                $DeploymentPackage 
                Write-Log -log "Found $($RemoveContentIDs.Count) updates that will be removed from package name `"$($DeploymentPackage.Name)`" with a package id of $($DeploymentPackage.PackageID)"
                $AllContentid = $SUDPData.sms_softwareupdate.ci_id | Get-Unique
                ForEach($ContentID in $AllContentID){ 
                    
                    $UpdateName = (Get-CMSoftwareUpdate -fast -id $Contentid).LocalizedDisplayName
                    Write-Log -log "Removing $($UpdateName) from $($DeploymentPackage.Name) with a package id of $($DeploymentPackage.PackageID)"

                    }
                $ErrorActionPreference = "SilentlyContinue"
                $DeploymentPackage.RemoveContent($RemoveContentIDs,$True) | Out-Null 
            }
        }
        
        #Remove Empty Deployment Packages
        Write-log -log "Sleeping 30 seconds for metadata replication after cleanup"
        Start-Sleep 30 
        $EmptyPackages = Get-CMSoftwareUpdateDeploymentPackage | ? {$_.PackageSize -eq 0}
        ForEach($EmptyPackage in $EmptyPackages){
            Write-log -log "Deployment Package $($EmptyPackage.Name) contains 0 updates and will be removed."
            Remove-CMSoftwareUpdateDeploymentPackage -Id $EmptyPackage.PackageID -Force
            }
        

    }

Else { Write-Log -log "No action taken, in delay period" }

Write-Log -log "Cleanup-UpdateDeployments Complete"

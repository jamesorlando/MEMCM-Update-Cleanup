# MEMCM-Update-Cleanup

See PDF for detailed instructions for setup with Status Message Filters in the MEMCM Console. 

    Script name: Remove-ExpiredSupersededUpdates
    Author: James Orlando
    Contact: James.Orlando@microsoft.com
    Date Created: 11-20-2019
    Date Modified: 11-25-2020

    Example: 
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -file <Location of Remove-ExpiredSupersededUpdates.ps1> -SiteCode <Site Code> -ProviderMachineName <Primary Site FQDN> -Delay <DelayDays> 
    
    SiteCode: <Mandatory> Three digit site code
    ProviderMachineName: FQDN of SMS Provider 
    Delay: Number of days to delay cleanup after Patch Tuesday. If your ADR Runs +2 days after Patch Tuesday you may not want superseeded updates removed from deployments until the updates that superseded them are deployed
    
    C:\Windows\System32\WindowsPowerShell\v1.0\powershell.exe -executionpolicy bypass -file "E:\Status Message Scripts\Remove-ExpiredSupersededUpdates.ps1" -SiteCode JPO -ProviderMachineName cm01.pfejameso.com -Delay 2
    In the example above, no updates will be removed on Patch Tuesday or the next two days. 
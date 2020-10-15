# MEMCM-Update-Cleanup

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

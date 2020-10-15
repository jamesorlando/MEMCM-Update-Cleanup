# MEMCM-Update-Cleanup

WSUS-CLEANUP-UPDATES
    
    Runs WSUS cleanup task using stored procedures in WSUS database
    thus avoiding timeout errors that may occur when running WSUS Cleanup Wizard.

    The script is intended to run as a scheduled task on WSUS server
    but can also be used remotely. $SqlServer and $SqlDB variables 
    must be defined before running the script on a server without WSUS.

    Version 4

    Version history:

    4    Added database connection state check before deleting an 
         unused update: the script will now attempt to reestablish
         connection if broken.

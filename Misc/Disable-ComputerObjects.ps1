<#

    .SYNOPSIS

    This script processes inactive AD objects based on a user-specified time span, and then moves them to an Inactive OU and deletes the Configuration Manager object on the specified CM Site. Specifics can be provided in an XML or manually entered into the script. 

    .DESCRIPTION

    This script is generalized as-is but it should be customized alongside an XML file (which would be accessible only to Domain Admins, ideally). This script requires the ActiveDirectory module be available as well as the ConfigurationManager module. The use of the Verbose parameter is recommended. Written by Michael Brady.
    
    .PARAMETER XMLpath

    This is an optional parameter in lieu of providing the XML path in the script.

    .EXAMPLE

    .\Disable-ComputerObjects.ps1 \\CONTOSO\disableobjects.xml

    Computer objects will be disabled/removed based on the xml specified.

#>

[CmdletBinding()]
    Param(
        [Parameter(Mandatory=$False,Position=1)]
            [string]$XMLpath
        )

# Import XML file and assign variables
If (-Not($XMLpath)) {
    [xml]$XMLData = [xml](Get-Content -Path "")
    }
    Else {
        If (Test-Path ($XMLpath)) {
            [xml]$XMLData = [xml](Get-Content -Path $XMLpath)
            }
            Else {
                Throw "XML path given could not be found. Please check the value given for the parameter and try again."
                }
        }
    $CMSite = $XMLData.ObjectCleanup.CM.CMSite
    $CMTopCollection = $XMLData.ObjectCleanup.CM.CMTopCollection
    $CMSiteServer = $XMLData.ObjectCleanup.CM.CMSiteServer

    $InactiveTimeSpan = $XMLData.ObjectCleanup.AD.InactiveTimeSpan
    $ADServer = $XMLData.ObjectCleanup.AD.ADServer
    $ADSearchBase = $XMLData.ObjectCleanup.AD.ADSearchBase
    $ADInactiveContainer = $XMLData.Objectcleanup.AD.ADInactiveContainer

$OriginalPath = (Get-Location).Path

# Make sure the relevant modules can be loaded: Configuration Manager and ActiveDirectory
If (-Not((Get-Module).Name.Contains("ConfigurationManager"))) {
    If (Test-Path $env:SMS_ADMIN_UI_PATH) {
        $SplitPathArray = $env:SMS_ADMIN_UI_PATH.Split("\")
        $ModulePath = $SplitPathArray[0] + "\" + $SplitPathArray[1] + "\" + $SplitPathArray[2] + "\" + $SplitPathArray[3] + "\" + "ConfigurationManager.psd1"
        $VerbosePreference = "SilentlyContinue" ; Import-Module $ModulePath ; $VerbosePreference = "Continue"
        New-PSDrive -PSProvider CMSite -Name $CMSite -Root $CMSiteServer
        }
        Else {
            Throw "Configuration Manager module could not be located or loaded. Exiting script."
            }
        }
    Else {
        Write-Verbose "Configuration Manager module already loaded."
        }

# If I don't control the output here, with the Verbose paramater specified it will list all modules which gets messy
$VerbosePreference = "SilentlyContinue" ; $ModuleList = Get-Module -ListAvailable ; $VerbosePreference = "Continue"
If (-Not(($ModuleList).Name.Contains("ActiveDirectory"))) {
    Throw "Active Directory module could not be loaded. Exiting script."
    }
    Else {
        Write-Verbose "Active Directory module can be loaded."
        }

$ADInactive = Search-ADAccount -AccountInactive -Timespan $InactiveTimeSpan -SearchBase "$ADSearchBase" -server $ADServer
$PCNames = $ADInactive.Name

# Clean up objects in AD; you can move to an inactive OU or alternatively delete with Remove-ADObject
Foreach ($ADDevice in $ADInactive) {
    Write-Verbose "Moving ($ADDevice.Name) to Inactive OU"
    Move-ADObject -Identity $ADDevice -TargetPath $ADInactiveContainer -Server $ADServer
    }

# Clean up same objects in Configuration Manager
Foreach ($CMDeviceName in $PCNames) {
    Set-Location "$CMSite`:\"
    # Controlling the verbose output here by disabling what would pass through from the ConfigMgr module. It's not as helpful and would be redundant.
    $VerbosePreference = "SilentlyContinue" ; $CMDevices = Get-CMDevice -Name $CMDeviceName -CollectionName "$CMTopCollection" | Select-Object -Property ResourceID, Name ; $VerbosePreference = "Continue"
    If (-Not($CMDevices -eq $null)) {
       Write-Verbose "Deleting CM Device $CMDeviceName"
       Remove-CMDevice -DeviceId $CMDevices.ResourceId -Force
        }
        Else {
            Write-Verbose "CM Device not found: $CMDeviceName"
            }
    $CMDevices = $null
    }

    # Switch back to whatever path you were on before, instead of staying on the CMSite PSDrive
    Set-Location $OriginalPath
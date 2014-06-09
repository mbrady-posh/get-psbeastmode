<#

    .SYNOPSIS

    This script installs software silently for use in a Configuration Manager environment and contains various configuration and clean-up functionality. A robust log is also created.

    .DESCRIPTION

    This script requires information be provided in the form of the software name, version, setup file, etc in order to function. Uninstalling old versions and performing configuration is also possible when the appropriate functions are edited. This script should be run as administrator. Some examples are provided. Written by Michael Brady.

    .EXAMPLE

    .\Install-Software.ps1

    Install software silently, performs a hardware inventory cycle to update the Configuration Manager database and logs to C:\Windows\CCM\ConfigMgrOps.log.

#>


[CmdletBinding()]
    Param( )

# Variables to be set before doing anything
# Set Constants
Set-Variable LogInfo -Option Constant -value 1 -Scope Script
Set-Variable LogWarning -Option Constant -value 2 -Scope Script
Set-Variable LogError -Option Constant -value 3 -Scope Script

# Set some common variables
$ScriptName = $MyInvocation.MyCommand.Name
$OSType = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty OSArchitecture
If ($OSType -eq "64-bit") {
    $WinSysFolder = "SysWow64" 
    }
    Else { $WinSysFolder = "System32" 
        }
$Returncode = 0

# Variables for common paths
$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$ScriptParentPath = Split-Path (Split-Path $MyInvocation.MyCommand.Path)
$PSPath = "[System.Diagnostics.Process]::GetCurrentProcess().Path"
$CCMPath = "$env:windir\ccm"
$MiniNTPath = "$env:SystemDrive\MININT\SMSOSD"
$PublicDesktop = "$env:PUBLIC\Desktop"

################################################
# Set software information
$SoftwareTitle = ""
$SoftwareVersion = ""
$SoftwareInstallFile = ""
$SoftwareSetupSyntax = ""
################################################

# Choose log file to use
function New-LogFile() {
    $LogFilePaths =  "$CCMPath\Logs\ConfigMgrOps.log", "$MiniNTPath\Logs\ConfigMgrOps.log","$env:TEMP\ConfigMgrOps.log"
    Foreach ($LogFilePath in $LogFilePaths) {
        $script:NewLogError = $null
        $script:ConfigMgrLogFile = $LogFilePath
        Add-LogEntry "Log file successfully intialized." $LogInfo
        If (-Not($script:NewLogError)) { break }
        }
        If ($script:NewLogError) {
            $script:Returncode = 1
            Exit $script:Returncode
            }
    }

# Logging Info
function Add-LogEntry ($LogMessage, $Messagetype) {
    # Date and time is set to the SMS Trace standard
    Add-Content $script:ConfigMgrLogFile "<![LOG[$LogMessage]LOG]!><time=`"$((Get-Date -format HH:mm:ss)+".000+300")`" date=`"$(Get-Date -format MM-dd-yyyy)`" component=`"$ScriptName`" context=`"`" type=`"$Messagetype`" thread=`"`" file=`"powershell.exe`">"  -Errorvariable script:NewLogError
    }

# Make the script close the log with a divider and exit with return code gathered earlier
function Exit-Script() {
    Add-LogEntry "Closing the log file." "$LogInfo"
    Add-LogEntry "******************************************************************************************************************************************************" "$LogInfo"
    Exit $script:Returncode    
    }

# Uninstall old versions
function Uninstall-OldVersions() {
    Add-LogEntry "Uninstalling old versions of the software." "$LogInfo"
    Start-Process $env:windir\$WinSysFolder\msiexec.exe '/x {x} /qn /norestart' -PassThru | Wait-Process -Timeout 600
    }

# Software install and configuration
# Make sure to change the timeout to match the application. 10 minutes may not be enough.
function Install-Software() {
    If ($SoftwareInstallFile.EndsWith(".msi")) {
        $SoftwareFilePath = "$env:windir\$winsysfolder\msiexec.exe"
        $SoftwareSetupSyntax = "/i " + """" + $ScriptPath + "\" + $SoftwareInstallFile + """ " + $SoftwareSetupSyntax
        $InstallCommandLine = (Start-Process $SoftwareFilePath $SoftwareSetupSyntax -PassThru)
        }
        Else {
            $SoftwareFilePath = "$ScriptPath\$SoftwareInstallFile"
            $InstallCommandLine = (Start-Process $SoftwareFilePath $SoftwareSetupSyntax -PassThru)
            }
    Add-LogEntry "Attempting to install software $SoftwareTitle, $SoftwareVersion" "$LogInfo"

   If (Test-Path $SoftwareFilePath) {
        If (($Host.Version.Major -ne 1) -and ($Host.Version.Major -ne 2)) {
            Add-LogEntry "Disabling open file security warning" "$LogInfo"
            # Only functional on PS 3+; supplying the old cmd style way as well
            Unblock-File -Path $SoftwareFilePath
            Start-Process "$env:windir\system32\cmd.exe" "/c echo.>""$SoftwareFilePath"":Zone.Identifier"
            }
        Add-LogEntry "Running command line: `"$SoftwareFilePath`" $SoftwareSetupSyntax" "$LogInfo"
        $InstallCommandLine | Wait-Process -Timeout 600
        $script:Returncode = ($InstallCommandLine).ExitCode
        Add-LogEntry "Finished running command line." "$LogInfo"
        Verify-Install 
		}
        Else { $script:Returncode = "1"
            Add-LogEntry "File path $SoftwareFilePath doesn't appear to exist. Exiting with error." "$LogError"
            Verify-Install 
			}
    }

    # Examine the return code and react appropriately
function Verify-Install() {
    If ($script:Returncode -eq "0") {
        Add-LogEntry "$SoftwareTitle, $SoftwareVersion appears to have installed successfully." "$LogInfo" }
        ElseIf ($script:Returncode -eq "3010") {
            Add-LogEntry "$SoftwareTitle, $SoftwareVersion appears to have installed successfully but a reboot is required." "$LogWarning" }
        Else {
            Add-LogEntry "Return code $script:Returncode" "$LogError"
            Add-LogEntry "There was a problem while installing $SoftwareTitle, $SoftwareVersion. Exiting with error." "$LogError"
            Exit-Script
            Exit $script:Returncode }
    }

    # Remove shortcuts and any other undesirable files or keys
function Remove-Shortcuts() {
    Add-LogEntry "Attempting to remove shortcuts from public desktop." "$LogInfo"
    $ShortcutFile = "$PublicDesktop\$SoftwareTitle.lnk"
    Add-LogEntry "Searching for $ShortcutFile" "$LogInfo"
    If (Test-Path $ShortcutFile) {
        Add-LogEntry "File exists, removing." "$LogInfo"
        Remove-Item $ShortcutFile }
    }

 # Use this function to do misc configuration, such as copying config. files
function Install-SoftwareConfiguration() {
    Add-LogEntry "Starting install configuration." "$LogInfo"
    If ((Test-Path "$ScriptPath\file.cfg") -and (Test-Path "${env:ProgramFiles(x86)}\$SoftwareTitle")) {
        Add-LogEntry "Copying file.cfg." "$LogInfo"
        Copy-Item "$ScriptPath\file.cfg" "${env:ProgramFiles(x86)}\$SoftwareTitle\" }
     If ((Test-Path "$ScriptPath\file.cfg") -and (Test-Path "${env:ProgramFiles}\$SoftwareTitle")) {
        Add-LogEntry "Copying file.cfg." "$LogInfo"
        Copy-Item "$ScriptPath\file.cfg" "${env:ProgramFiles}\$SoftwareTitle\" }
    }
     
# Update ConfigMgr Hardware Inventory
function Get-HardwareInventory() {
    $SMSClient = [wmiclass] "\\$env:COMPUTERNAME\root\ccm:SMS_Client"
    $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}")
    Add-LogEntry "Running Hardware Inventory." "$LogInfo"
    }

# Execute
New-LogFile
#Uninstall-OldVersions
Install-Software
#Remove-Shortcuts
#Install-SoftwareConfiguration
Get-HardwareInventory
Exit-Script
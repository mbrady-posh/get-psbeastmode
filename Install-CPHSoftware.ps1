#
# Outline for College of Public Health PowerShell scripts
# Last Edited by Michael Brady 5-16-2014
# TODO: open file security warning
# TODO: choose log based on permissions
# TODO: MSI logic
# TODO: Fix dates/times usage
#
# Make sure Execution Policy is set
Set-ExecutionPolicy RemoteSigned

# Variables to be set before doing anything
# Set Constants
Set-Variable LogInfo -Option Constant -value 1 -Scope Script
Set-Variable LogWarning -Option Constant -value 2 -Scope Script
Set-Variable LogError -Option Constant -value 3 -Scope Script

# Set standard time and date variables; SMS Trace standard
$DATE = Get-Date -format MM-dd-yyyy
$TIME = (Get-Date -format HH:mm:ss)+".000+300"

# Declare common string variables
$ScriptName = $MyInvocation.MyCommand.Name
$OSType = Get-WmiObject -Class Win32_OperatingSystem | Select-Object -ExpandProperty OSArchitecture
If ($OSType -eq "64-bit") {
    $WinSysFolder = "SysWow64" }
    Else { $WinSysFolder = "System32" }
$Returncode = 0

# Variables for common paths
$ScriptPath = Split-Path $MyInvocation.MyCommand.Path
$ScriptParentPath = Split-Path (Split-Path $MyInvocation.MyCommand.Path)
$PSPath = "[System.Diagnostics.Process]::GetCurrentProcess().Path"
$CCMPath = "$env:windir\ccm"
$MiniNTPath = "$env:SystemDrive\MININT\SMSOSD"
$PublicDesktop = "$env:PUBLIC\Desktop"

# Declare common objects
$objShell = New-Object -ComObject Shell.Application


################################################
# Set software information
$SoftwareTitle = ""
$SoftwareVersion = ""
$SoftwareInstallFile = ""
$SoftwareSetupSyntax = ""
################################################

# Choose log file to use
function New-LogFile {
    If (Test-Path "$CCMPath\Logs")
        { $global:CPHLogFile = "$CCMPath\Logs\CPHConfigMgrOps.log" }
        ElseIf (Test-Path "$MiniNTPath") 
            { $global:CPHLogFile = "$MiniNTPath\Logs\CPHConfigMgrOps.log" }
        ElseIf (Test-Path "$env:TEMP") 
            { $global:CPHLogFile = "$env:TEMP\Logs\CPHConfigMgrOps.log" }
        Else { Write-EventLog -LogName System -Source "powershell.exe" -EventId 2 -EntryType Warning -Message "Script is aborting; no log could be created."
            $script:Returncode = 1
            Exit $script:Returncode }
        Add-LogEntry "Log file successfully created." "$LogInfo"
        }

# Logging Info; standard is to match SMS Trace
function Add-LogEntry ($LogMessage, $Messagetype) {
    Add-Content $CPHLogFile "<![LOG[$LogMessage]LOG]!><time=`"$TIME`" date=`"$DATE`" component=`"$ScriptName`" context=`"`" type=`"$Messagetype`" thread=`"`" file=`"powershell.exe`">"
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
function Install-CPHSoftware() {
    $SoftwareFilePath = "$ScriptPath\$SoftwareInstallFile"
    $InstallCommandLine = (Start-Process $SoftwareFilePath $SoftwareSetupSyntax -PassThru)
    Add-LogEntry "Attempting to install software $SoftwareTitle, $SoftwareVersion" "$LogInfo"

    If (Test-Path $SoftwareFilePath) {
        If (($Host.Version.Major -ne 1) -and ($Host.Version.Major -ne 2)) {
            Add-LogEntry "Disabling open file security warning" "$LogInfo"
            # Only functional on PS 3+
            Unblock-File $SoftwareFilePath
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

function Remove-Shortcuts() {
    Add-LogEntry "Attempting to remove shortcuts from public desktop." "$LogInfo"
    $ShortcutFile = "$PublicDesktop\$SoftwareTitle.lnk"
    Add-LogEntry "Searching for $ShortcutFile" "$LogInfo"
    If (Test-Path $ShortcutFile) {
        Add-LogEntry "File exists, removing." "$LogInfo"
        Remove-Item $ShortcutFile }
    }

 #Use this function to do misc configuration, such as copying config. files
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
function Get-HardwareInventory () {
    $SMSClient = [wmiclass] "\\$env:COMPUTERNAME\root\ccm:SMS_Client"
    $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}")
    Add-LogEntry "Running Hardware Inventory." "$LogInfo"
    }

# Execute
New-LogFile
#Uninstall-OldVersions
Install-CPHSoftware
#Remove-Shortcuts
#Install-SoftwareConfiguration
Get-HardwareInventory
Exit-Script
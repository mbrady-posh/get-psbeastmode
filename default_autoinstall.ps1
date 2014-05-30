#
# Outline for College of Public Health PowerShell scripts
# Last Edited by Michael Brady 5-16-2014
# TODO: open file security warning
# TODO: choose log based on permissions
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
function CreateLogFile {
    If (Test-Path "$CCMPath\Logs")
        { $global:CPHLogFile = "$CCMPath\Logs\CPHConfigMgrOps.log" }
        ElseIf (Test-Path "$MiniNTPath") 
            { $global:CPHLogFile = "$MiniNTPath\Logs\CPHConfigMgrOps.log" }
        ElseIf (Test-Path "$env:TEMP") 
            { $global:CPHLogFile = "$env:TEMP\Logs\CPHConfigMgrOps.log" }
        Else { Write-EventLog -LogName System -Source "powershell.exe" -EventId 2 -EntryType Warning -Message "Script is aborting; no log could be created."
            $script:Returncode = 1
            Exit $script:Returncode }
        AppendtoLog "Log file successfully created." "$LogInfo"
        }

# Logging Info; standard is to match SMS Trace
function AppendtoLog ($LogMessage, $Messagetype) {
    Add-Content $CPHLogFile "<![LOG[$LogMessage]LOG]!><time=`"$TIME`" date=`"$DATE`" component=`"$ScriptName`" context=`"`" type=`"$Messagetype`" thread=`"`" file=`"powershell.exe`">"
    }
# Make the script close the log with a divider and exit with return code gathered earlier
function EndScript() {
    AppendtoLog "Closing the log file." "$LogInfo"
    AppendtoLog "******************************************************************************************************************************************************" "$LogInfo"
    Exit $script:Returncode    
    }

# Uninstall old versions
function UninstallOldVersions() {
    AppendtoLog "Uninstalling old versions of the software." "$LogInfo"
    Start-Process $env:windir\$WinSysFolder\msiexec.exe '/x {x} /qn /norestart' -PassThru | Wait-Process -Timeout 600
    }

# Software install and configuration
# Make sure to change the timeout to match the application. 10 minutes may not be enough.
function InstallSoftware() {
    $SoftwareFilePath = "$ScriptPath\$SoftwareInstallFile"
    $InstallCommandLine = (Start-Process $SoftwareFilePath $SoftwareSetupSyntax -PassThru)
    AppendtoLog "Attempting to install software $SoftwareTitle, $SoftwareVersion" "$LogInfo"

    If (Test-Path $SoftwareFilePath) {
        If (($Host.Version.Major -ne 1) -and ($Host.Version.Major -ne 2)) {
            AppendtoLog "Disabling open file security warning" "$LogInfo"
            # Only functional on PS 3+
            Unblock-File $SoftwareFilePath
            }
        AppendtoLog "Running command line: `"$SoftwareFilePath`" $SoftwareSetupSyntax" "$LogInfo"
        $InstallCommandLine | Wait-Process -Timeout 600
        $script:Returncode = ($InstallCommandLine).ExitCode
        AppendtoLog "Finished running command line." "$LogInfo"
        VerifyInstall 
		}
        Else { $script:Returncode = "1"
            AppendtoLog "File path $SoftwareFilePath doesn't appear to exist. Exiting with error." "$LogError"
            VerifyInstall 
			}
    }

function VerifyInstall() {
    If ($script:Returncode -eq "0") {
        AppendtoLog "$SoftwareTitle, $SoftwareVersion appears to have installed successfully." "$LogInfo" }
        ElseIf ($script:Returncode -eq "3010") {
            AppendtoLog "$SoftwareTitle, $SoftwareVersion appears to have installed successfully but a reboot is required." "$LogWarning" }
        Else {
            AppendtoLog "Return code $script:Returncode" "$LogError"
            AppendtoLog "There was a problem while installing $SoftwareTitle, $SoftwareVersion. Exiting with error." "$LogError"
            EndScript
            Exit $script:Returncode }
    }

function CleanPublicDesktop() {
    AppendtoLog "Attempting to remove shortcuts from public desktop." "$LogInfo"
    $ShortcutFile = "$PublicDesktop\$SoftwareTitle.lnk"
    AppendtoLog "Searching for $ShortcutFile" "$LogInfo"
    If (Test-Path $ShortcutFile) {
        AppendtoLog "File exists, removing." "$LogInfo"
        Remove-Item $ShortcutFile }
    }

 #Use this function to do misc configuration, such as copying config. files
function InstallConfiguration() {
    AppendtoLog "Starting install configuration." "$LogInfo"
    If ((Test-Path "$ScriptPath\file.cfg") -and (Test-Path "${env:ProgramFiles(x86)}\$SoftwareTitle")) {
        AppendtoLog "Copying file.cfg." "$LogInfo"
        Copy-Item "$ScriptPath\file.cfg" "${env:ProgramFiles(x86)}\$SoftwareTitle\" }
     If ((Test-Path "$ScriptPath\file.cfg") -and (Test-Path "${env:ProgramFiles}\$SoftwareTitle")) {
        AppendtoLog "Copying file.cfg." "$LogInfo"
        Copy-Item "$ScriptPath\file.cfg" "${env:ProgramFiles}\$SoftwareTitle\" }
    }
     
# Update ConfigMgr Hardware Inventory
function RunHardwareInventory () {
    $SMSClient = [wmiclass] "\\$env:COMPUTERNAME\root\ccm:SMS_Client"
    $SMSClient.TriggerSchedule("{00000000-0000-0000-0000-000000000001}")
    AppendtoLog "Running Hardware Inventory." "$LogInfo"
    }

# Execute
CreateLogFile
#UninstallOldVersions
InstallSoftware
#CleanPublicDesktop
#InstallConfiguration
RunHardwareInventory
EndScript
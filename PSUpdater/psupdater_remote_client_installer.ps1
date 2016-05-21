Param(
    [Parameter(Mandatory=$True)][string]$Hostname
    )

Function Transform-Certificate {
[CmdletBinding()]
    param(
 [Parameter(Mandatory = $true, ValueFromPipeline = $true, ValueFromPipelineByPropertyName = $true)]
 [Security.Cryptography.X509Certificates.X509Certificate2]$cert
 )
    process {
        $temp = $cert.Extensions | ?{$_.Oid.Value -eq "1.3.6.1.4.1.311.20.2"}
 if (!$temp) {
            $temp = $cert.Extensions | ?{$_.Oid.Value -eq "1.3.6.1.4.1.311.21.7"}
 }
        $cert | Add-Member -Name Template -MemberType NoteProperty -Value $temp.Format(1) -PassThru
 }
}

$RemoteReg = Get-WmiObject -Class Win32_Service -ComputerName $($Hostname) | Where {$_.Name -like "RemoteRegistry"}

If ($RemoteReg.StartMode -eq "Disabled") {
    $RemoteReg.ChangeStartMode("Manual") | Out-Null
    $RemoteReg.StartService() | Out-Null
    }
    ElseIf ($RemoteReg.State -eq "Stopped") {
        $RemoteReg.StartService() | Out-Null
        }

$store = New-Object System.Security.Cryptography.X509Certificates.X509Store("\\$($Hostname)\My","LocalMachine")
$store.Open("ReadOnly")
$Certs = $store.Certificates
$script:scriptpath = split-path -parent $MyInvocation.MyCommand.Definition
$Computername = $(Get-wmiobject win32_computersystem -ComputerName $Hostname) | Foreach-Object {$("$($_.name).$($_.domain)").ToUpper()}

Foreach ($Cert in $certs) {
    $Cert = $cert | Transform-Certificate
    If ($Cert.Template -like "*WinRMSSL*") {
        $SelectedCert = $cert.Thumbprint
        Break
        }
    }

If (!($SelectedCert)) {
    "System has not installed WinRMSSL certificate. Exiting" | Add-Content "$($env:USERPROFILE)\desktop\psupdater_client_install_err.log" -force
    Exit 1
    }

Try {
    If (!(Test-Path "\\$($Hostname)\C`$\scripts")) {
        New-Item -ItemType Directory -Path "\\$($Hostname)\C`$\scripts" | Out-Null
        }
    Copy-Item "$($script:scriptpath)\Enable-WinRMHTTPS.ps1" -Destination "\\$($Hostname)\C`$\scripts\Enable-WinRMHTTPS.ps1" -Force
    Start-Process "schtasks.exe" "/Create /S $($Hostname) /SC ONCE /ST 00:01 /RU `"SYSTEM`" /TN `"Intrado\EnableWinRMHTTPS`" /TR `"powershell.exe -executionpolicy Bypass C:\scripts\Enable-WinRMHTTPS.ps1 $($Computername) $($SelectedCert)`"" -Wait
    Start-Sleep 5
    Start-Process "schtasks.exe" "/Run /S $($Hostname) /TN `"Intrado\EnableWinRMHTTPS`"" -Wait
    Do {
        Start-Sleep -Seconds 5
        }
        Until ( (schtasks.exe /S $($Hostname) /QUERY /TN Intrado\EnableWinRMHTTPS /V /FO List | Select-String "Status") -like "*Ready*")
    Start-Process "schtasks.exe" "/Delete /S $($Hostname) /TN `"Intrado\EnableWinRMHTTPS`" /F" -Wait
    Remove-Item "\\$($Hostname)\C`$\Scripts\Enable-WinRMHTTPS.ps1" -Force
    If (Test-Path "\\$($Hostname)\C`$\psupdater_client_install_err.log") {
        Throw "Enabling WinRM failed. Exiting"
        }
    }
    Catch {
        $($error[0]) | Add-Content "$($env:USERPROFILE)\desktop\psupdater_client_install_err.log" -force
        }

Try {
    Start-Process "schtasks.exe" "/Create /XML `"$($script:scriptpath)\psupdater_download.xml`" /TN Intrado\PSUpdater_Download /S $($Hostname)" -Wait
    Start-Process "schtasks.exe" "/Create /XML `"$($script:scriptpath)\psupdater_install.xml`" /TN Intrado\PSUpdater_Install /S $($Hostname)" -Wait
    }
    Catch {
        "Unable to create scheduled tasks. Exiting" | Add-Content "$($env:USERPROFILE)\desktop\psupdater_client_install_err.log" -force
        Exit 1
        }

Try {
    If (!(Test-Path "\\$($Hostname)\C`$\scripts")) {
        New-Item -ItemType Directory "\\$($Hostname)\C`$\scripts" | Out-Null
        }
    Copy-Item "$($script:scriptpath)\psupdater_client.ps1" -Destination "\\$($Hostname)\C`$\scripts\psupdater_client.ps1" -Force
    }
    Catch {
        "Copying script file failed. Exiting" | Add-Content "$($env:USERPROFILE)\desktop\psupdater_client_install_err.log" -force
        Exit 1
        }
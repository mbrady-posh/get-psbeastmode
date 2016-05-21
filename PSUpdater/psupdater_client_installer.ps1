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

$certs = Get-ChildItem Cert:\LocalMachine\My
$script:scriptpath = split-path -parent $MyInvocation.MyCommand.Definition
$Computername = $(Get-wmiobject win32_computersystem) | Foreach-Object {$("$($_.name).$($_.domain)").ToUpper()}

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
    Start-Process "schtasks.exe" "/Create /XML `"$($script:scriptpath)\psupdater_download.xml`" /TN Intrado\PSUpdater_Download" -Wait
    Start-Process "schtasks.exe" "/Create /XML `"$($script:scriptpath)\psupdater_install.xml`" /TN Intrado\PSUpdater_Install" -Wait
    }
    Catch {
        "Unable to create scheduled tasks. Exiting" | Add-Content "$($env:USERPROFILE)\desktop\psupdater_client_install_err.log" -force
        Exit 1
        }

If ($((get-item "wsman:\localhost\service\defaultports\https").value) -eq 5986) {
    $connection = (New-Object Net.Sockets.TcpClient)
    $ErrorActionPreference = "SilentlyContinue"
    $connection.Connect("127.0.0.1",5986)
    $ErrorActionPreference = "Continue"
    Try {
        If (!($connection.Connected)) {
            $connection.Close()
            Start-Process "winrm" "create winrm/config/Listener?Address=*+Transport=HTTPS @{Hostname=`"$($Computername)`";CertificateThumbprint=`"$($SelectedCert)`"}" -Wait
            If ((Get-Service WinRM).Status -ne "Running") {
                Start-Service WinRM
                }
            }
            Else {
                "Port already in use. Assuming this is an existing WinRM listener." | Add-Content "$($env:USERPROFILE)\desktop\psupdater_client_install_warn.log" -force
                }
        }
            Catch {
                "$($error[0])" | Add-Content "$($env:USERPROFILE)\desktop\psupdater_client_install_err.log" -force
                "Enabling WinRM failed. Exiting" | Add-Content "$($env:USERPROFILE)\desktop\psupdater_client_install_err.log" -force
                Exit 1
                }
      }
      Else {
        "Default WinRM HTTPS port not standard (5986). Exiting" | Add-Content "$($env:USERPROFILE)\desktop\psupdater_client_install_err.log" -force
        Exit 1
        }

Try {
    If (!(Test-Path C:\scripts)) {
        New-Item -ItemType Directory "C:\scripts" | Out-Null
        }
    Copy-Item "$($script:scriptpath)\psupdater_client.ps1" -Destination "C:\scripts\psupdater_client.ps1" -Force
    }
    Catch {
        "Copying script file failed. Exiting" | Add-Content "$($env:USERPROFILE)\desktop\psupdater_client_install_err.log" -force
        Exit 1
        }
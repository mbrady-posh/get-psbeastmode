Param(
    $Computername,$SelectedCert
    )

If ($((get-item "wsman:\localhost\service\defaultports\https").value) -eq 5986) {
    $connection = (New-Object Net.Sockets.TcpClient)
    $ErrorActionPreference = "SilentlyContinue"
    $connection.Connect("localhost",5986)
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
                $connection.Close()
                "Port already in use. Assuming this is an existing WinRM listener." | Add-Content "C:\psupdater_client_install_warn.log" -force
                }
        }
            Catch {
                "$($error[0])" | Add-Content "C:\psupdater_client_install_err.log" -force
                "Enabling WinRM failed. Exiting" | Add-Content "C:\psupdater_client_install_err.log" -force
                Exit 1
                }
      }
      Else {
        "Default WinRM HTTPS port not standard (5986). Exiting" | Add-Content "C:\psupdater_client_install_err.log" -force
        Exit 1
        }
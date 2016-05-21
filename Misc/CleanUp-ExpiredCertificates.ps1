$script:scriptpath = split-path -parent $MyInvocation.MyCommand.Definition

$CSV = Import-CSV "$Script:scriptpath\certs.csv" | Where {$_.FQDN -like "*domain.com"}

$i = 0
$CSV | Foreach-Object {
    $i++
    $Remoteregistry = get-WmiObject Win32_Service -ComputerName $($_.FQDN) | Where {$_.Name -like "RemoteRegistry"}
    If ($RemoteRegistry.StartMode -eq "Disabled") {
        $RemoteRegistry.ChangeStartMode("Manual")
        }
    $Remoteregistry.StartService()

    $store = New-Object System.Security.Cryptography.X509Certificates.X509Store("\\$($_.FQDN)\My","LocalMachine")
    $store.Open("ReadWrite")
    $CerttoRemove = $store.Certificates.Find("FindByThumbprint","$($_.Thumbprint)",$False)
    If ($CerttoRemove) {
        $CerttoRemove.Export("Cert") | Set-Content "$($env:userprofile)\desktop\$($_.FQDN)-$($i).cer" -Encoding Byte -Force
        If (Test-Path "$($env:userprofile)\desktop\$($_.FQDN)-$($i).cer") {
            $store.Remove($CerttoRemove[0])
            }
        }
    $Store = $null
    $CerttoRemove = $null
    }
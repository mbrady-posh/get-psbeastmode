# ConfigMgrUninstall
$configmgrKey="IdentifyingNumber=`"`{2609EDF1-34C4-4B03-B634-55F3B3BC4931`}`",Name=`"Configuration Manager Client`",version=`"4.00.6487.2000`""
#manual uninstall: msiexec.exe /x {2609EDF1-34C4-4B03-B634-55F3B3BC4931}

$servers = Get-Content "C:\users\mbrady2\downloads\serverlistfinal.txt"
$Failures = @()
$i = 0

Function UninstallProduct($Computer,$classkey) {
    $ErrorActionPreference = "Stop"
    Try {
        $ConfigMgrInstance = [wmi]"\\$($Computer)\root\cimv2:Win32_Product.$($classkey)"
        $ConfigMgrInstance.Uninstall() | Out-Null
        }
        Catch {
            $Failures += New-Object -TypeName PSCustomObject -Property $(@{"Name"=$Server;"Error"=$_})
            }
            Finally {
                $ErrorActionPreference = "Continue"
                }
    }

Foreach ($server in $Servers) {
    $i++
    Write-Progress -Activity "Uninstalling Configuration Manager Client" -PercentComplete ($i / $servers.count * 100) -CurrentOperation "$server"
    UninstallProduct $server $configmgrKey
    }

$Failures
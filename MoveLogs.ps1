$OriginalEAP = $ErrorActionPreference
$LogFolderName = "$($env:COMPUTERNAME)$(Get-Date -format h_mm-M_d_yy)"
Try {
    $ErrorActionPreference = "Stop"
    If (Test-Path "\\server") {
        New-Item -ItemType Directory "\\server\$LogFolderName" -Force | Out-Null
        New-Item -ItemType Directory "\\server\$LogFolderName\SMSTSLog" -Force | Out-Null
        }
    }
    Catch {
        Throw "Remote log directory is not accessible."
        }
    Finally {
        $ErrorActionPreference = $OriginalEAP
        }
Try {
    $ErrorActionPreference = "Stop"
    Start-Process "C:\windows\system32\reg.exe" "add `"HKEY_LOCAL_MACHINE\Software\Microsoft\CCM\Logging\@Global`" /v LogDirectory /d `"\\server\$LogFolderName`" /f"
    }
    Catch {
        Throw "Unable to set new log location in the registry."
        }
    Finally {
        $ErrorActionPreference = $OriginalEAP
        }
Try {
    $ErrorActionPreference = "Stop"
    If (Test-Path "C:\windows\ccm\logs") {
        Copy-Item "C:\windows\ccm\logs\*" "\\server\$LogFolderName\movedlogs\" -Recurse -Force
        }
    }
    Catch {
        Throw "Unable to copy existing logs to remote location."
        }
    Finally {
        $ErrorActionPreference = $OriginalEAP
        }
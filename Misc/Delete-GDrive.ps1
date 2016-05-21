[CmdletBinding()]

Param(
    [string]$Infile = "$($env:userprofile)\desktop\gdrives.txt"
    )

If (!(Test-Path $Infile)) {
    Exit 0
    }

[array]$GDrives += Get-Content $Infile -Force
Remove-Item $Infile -Force

$Result = Foreach ($GDrive in $GDrives) {
    $Username = $Gdrive | Split-Path -Leaf
        $ServerName = ($GDrive -Split "\\" | Where { $_ })[0]
        [array]$Log += Invoke-Command -UseSSL -ComputerName "$($ServerName)" -ArgumentList $Username,$GDrive -ScriptBlock {
            Param( $Username,$GDrive )
            $Share = ($GDrive -Split "\\" | Where { $_ })[1]
            $LocalPath = "$((Get-WmiObject Win32_Share | Where {$_.Name -eq $Share}).Path)\$Username"
            If (Test-Path $LocalPath) {
                [array]$Log += "$($LocalPath) already exists on $($env:COMPUTERNAME)."
                }
                Else {
                    Try {
                        New-Item -ItemType Directory -Path $LocalPath | Out-Null
                        Test-Path $LocalPath
                        [array]$Log += "$($LocalPath) created."
                        }
                        Catch {
                            [array]$Log += "An error was encountered while creating $($LocalPath)."
                            }
                    Try {
                        icacls.exe $LocalPath /q /t /grant domain\$($Username):`(OI`)`(CI`)M > $null
                        $ACL = Get-ACL $LocalPath -Include $Username ; If ($ACL -eq $null) { Throw "Error" }
                        [array]$Log += "Successfully set permissions on $($LocalPath)."
                        }
                        Catch {
                            [array]$Log += "An error was encountered while setting permissions on $($LocalPath)."
                            }
                    }
            Return $Log
            }
        If ((dfsutil link "\\domain\home\$($Username)") -like "*Element not found.*") {
                Try {
                    dfsutil link add "\\domain\home\$($Username)" $($GDrive) > $null
                    Test-Path "\\domain\home\$($Username)"
                    [array]$Log += "DFS link \\domain\home\$($Username) created."
                    }
                    Catch {
                        [array]$Log += "There was a problem creating DFS link \\domain\home\$($Username)"
                        }
                }
                Else {
                    [array]$Log += "The DFS link \\domain\home\$($Username) already exists."
                    }
        [array]$Log
        }

Return $Result
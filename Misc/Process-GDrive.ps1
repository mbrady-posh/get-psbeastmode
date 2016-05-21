[CmdletBinding()]

Param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True,ValueFromPipelineByPropertyName=$True)][array]$Username,
    [string]$Outfile = "$($env:userprofile)\desktop\gdrives.txt"
    )

Begin {
    $servers = ""
    Foreach ($ADUser in $username) {
        Try {
            Get-ADUser $ADUser | Out-Null
            [array]$VerifiedUsers += $ADUser
            }
            Catch {
                [array]$UsersnotinAD += $ADUser
                }
        }
    }

Process {
        $UserShares = @()
        $UserShares += Foreach ($Server in $servers) {
            Invoke-Command -ComputerName $Server -UseSSL -ArgumentList $Server -ScriptBlock { 
                Param( $Server )
                $WMIShares = Get-WmiObject -Class Win32_Share | Where {$_.Name -like "Users_*"}
                Foreach ($wmishare in $wmishares) {
                    If ($WMishare.Path) {
                        $Driveletter = Split-Path $wmishare.Path -Qualifier
                        $WMIDisk = Get-WmiObject Win32_LogicalDisk | Where {$_.DeviceID -eq $Driveletter}
                        New-Object -TypeName PSCustomObject -Property @{"DriveLetter"=$Driveletter;"Share"="\\$($Server)\$($Wmishare.Name)";"SpaceFree"=$WMiDisk.FreeSpace;"NumFolders"=$((Get-Item -Path "$($wmishare.Path)").GetDirectories().Count) }
                        }
                    }
                }
            }
        $Chosenshare = $Usershares | Sort-Object -Property @{Expression={$($_.SpaceFree / $_.NumFolders)} } -Descending | Select -First 1
    }

End {
    Clear-Host
    Write-Output "The following G drives will be created:"
    Foreach ($User in $VerifiedUsers) {
        Add-Content $OutFile "$($ChosenShare.Share)\$($User)" -Force
        Write-Output "$($ChosenShare.Share)\$($User)"
        }
    If ($UsersnotinAD) {
        Write-Host -ForegroundColor Red "`nThe following users are not in AD, and no changes will be made:"
        Foreach ($baduser in $UsersnotinAD) {
            Write-Host -ForegroundColor Red $baduser
            }
        }
    }
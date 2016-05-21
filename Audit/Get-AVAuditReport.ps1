$OutFilePre = "$($env:TEMP)\Officescan client listing - $((((Get-wmiobject win32_computersystem).Domain -split "\.") | select -first 1).ToUpper()) - Servers $(Get-Date -Format 'MM.dd.yyyy').csv1"
$OutFile = "$($env:TEMP)\Officescan client listing - $((((Get-wmiobject win32_computersystem).Domain -split "\.") | select -first 1).ToUpper()) - Servers $(Get-Date -Format 'MM.dd.yyyy').csv"

$script:scriptpath = Split-Path -parent $MyInvocation.MyCommand.Definition
$SMTPServer = Get-Content "\\$((Get-wmiobject win32_computersystem).Domain)\sysvol\$((Get-wmiobject win32_computersystem).Domain)\scripts\smtpserver.txt"

Start-Process "C:\Program Files (x86)\Trend Micro\Officescan\PCCSRV\Web\Service\exportinfo.exe" "-c `"$($OutFile)1`"" -Wait

((Get-Content $OutfilePre | Select -First 1).TrimEnd(",")) -Replace ",,,,,","," | Out-File "$($Outfile)" -Force
(Get-Content $OutfilePre)[1..$((Get-Content $OutfilePre).Count - 1)] | Out-File "$($Outfile)" -Append
Remove-Item $OutfilePre

$CSV = Import-CSV -Path $Outfile
$CSV | Where {($_.Platform -like "*Server*") -or ($_.Platform -like "*NT*")} | Export-CSV -NoTypeInformation $Outfile
If ($CSV | Where {($_.Platform -notlike "*Server*") -and ($_.Platform -notlike "*NT*")}) {
    $CSV | Where {($_.Platform -notlike "*Server*") -and ($_.Platform -notlike "*NT*")} | Export-CSV -NoTypeInformation "$($env:TEMP)\Officescan client listing - $((((Get-wmiobject win32_computersystem).Domain -split "\.") | select -first 1).ToUpper()) - Workstations $(Get-Date -Format 'MM.dd.yyyy').csv"
    }

Do {
                    Try {
                        $ErrorActionPreference = "Stop"
                        $i++
                        Send-MailMessage -From "$($env:COMPUTERNAME)@domain.com" -To "unixserverreport@sharepoint" -Attachments $OutFile -Subject "Monthly AV Report" -SmtpServer $SMTPserver -Cc "cc"
                        $MailSuccess = $True
                        }
                        Catch {
                            Start-Sleep 20
                            }
                        Finally {
                            $ErrorActionPreference = "Continue"
                            }
                    }
                    Until ( $MailSuccess -eq $True -or $i -gt 4)

Do {
                    Try {
                        $ErrorActionPreference = "Stop"
                        $i++
                        Send-MailMessage -From "$($env:COMPUTERNAME)@domain" -To "unixserverreport@sharepoint" -Attachments "$($env:TEMP)\Officescan client listing - $((((Get-wmiobject win32_computersystem).Domain -split "\.") | select -first 1).ToUpper()) - Workstations $(Get-Date -Format 'MM.dd.yyyy').csv" -Subject "Monthly AV Report" -SmtpServer $SMTPserver
                        $MailSuccess = $True
                        }
                        Catch {
                            Start-Sleep 20
                            }
                        Finally {
                            $ErrorActionPreference = "Continue"
                            }
                    }
                    Until ( $MailSuccess -eq $True -or $i -gt 4)

Remove-Item $Outfile -ErrorAction SilentlyContinue
Remove-Item "$($env:TEMP)\Officescan client listing - $((((Get-wmiobject win32_computersystem).Domain -split "\.") | select -first 1).ToUpper()) - Workstations $(Get-Date -Format 'MM.dd.yyyy').csv" -ErrorAction SilentlyContinue
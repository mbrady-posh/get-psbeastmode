$OutFilePre = "$($env:TEMP)\Officescan client listing - $((((Get-wmiobject win32_computersystem).Domain -split "\.") | select -first 1).ToUpper()) - Servers $(Get-Date -Format 'MM.dd.yyyy').csv1"
$OutFile = "$($env:TEMP)\Officescan client listing - $((((Get-wmiobject win32_computersystem).Domain -split "\.") | select -first 1).ToUpper()) - Servers $(Get-Date -Format 'MM.dd.yyyy').csv"

$script:scriptpath = Split-Path -parent $MyInvocation.MyCommand.Definition
$SMTPServer = Get-Content "\\$((Get-wmiobject win32_computersystem).Domain)\sysvol\$((Get-wmiobject win32_computersystem).Domain)\scripts\smtpserver.txt"

Start-Process "C:\Program Files (x86)\Trend Micro\Officescan\PCCSRV\Web\Service\exportinfo.exe" "-c `"$($OutFile)1`"" -Wait

(Get-Content $OutfilePre | Select -First 1).TrimEnd(",") | Out-File "$($Outfile)" -Force
(Get-Content $OutfilePre)[1..$((Get-Content $OutfilePre).Count - 1)] | Out-File "$($Outfile)" -Append
Remove-Item $OutfilePre

$CSV = Import-CSV -Path $Outfile
$CSV | Where {$_.Platform -like "*Server*"} | Export-CSV -NoTypeInformation $Outfile
If ($CSV | Where {$_.Platform -notlike "*Server*"}) {
    $CSV | Where {$_.Platform -notlike "*Server*"} | Export-CSV -NoTypeInformation "$($env:TEMP)\Officescan client listing - $((((Get-wmiobject win32_computersystem).Domain -split "\.") | select -first 1).ToUpper()) - Workstations $(Get-Date -Format 'MM.dd.yyyy').csv"
    }

Do {
                    Try {
                        $ErrorActionPreference = "Stop"
                        $i++
                        Send-MailMessage -From "$($env:COMPUTERNAME)@domain.com" -To "doclibrary@sharepoint" -Attachments $OutFile -Subject "Monthly AV Report" -SmtpServer $SMTPserver
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
                        Send-MailMessage -From "$($env:COMPUTERNAME)@domain.com" -To "doclibrary@sharepoint" -Attachments "$($env:TEMP)\Officescan client listing - $((((Get-wmiobject win32_computersystem).Domain -split "\.") | select -first 1).ToUpper()) - Workstations $(Get-Date -Format 'MM.dd.yyyy').csv" -Subject "Monthly AV Report" -SmtpServer $SMTPserver
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

Copy-Item "C:\Program Files (x86)\Trend Micro\OfficeScan\PCCSRV\Log\update.log" "$($env:TEMP)\$(Get-Date -Format 'MM-yyyy')-AVUpdatelog.csv" -Force
[array]$CSVLines += "Date/Time,Update Method,Component1,Result,Notes"
[array]$CSVLines += Get-Content "$($env:TEMP)\$(Get-Date -Format 'MM-yyyy')-AVUpdatelog.csv" ; [array]$CSVLines | Out-File "$($env:TEMP)\$(Get-Date -Format 'MM-yyyy')-AVUpdatelog1.csv" -Encoding utf8
$CSVLines = $null
Remove-Item "$($env:TEMP)\$(Get-Date -Format 'MM-yyyy')-AVUpdatelog.csv" -Force

$NewCSV = Import-CSV "$($env:TEMP)\$(Get-Date -Format 'MM-yyyy')-AVUpdatelog1.csv"
$NewCSV = $NewCSV | ForEach-Object {$_."date/time" = $(Get-Date "$($_.'date/time'[0..3] -join '') $($_.'date/time'[4..5] -join '') $($_.'date/time'[6..7] -join '') $($_.'date/time'[8..9] -join ''):$($_.'date/time'[10..11] -join ''):$($_.'date/time'[12..13] -join '')" -Format "M/dd/yyyy HH:mm") ; $_}
$NewCSV = $NewCSV | Where {(($_.Result -eq 1) -and ($_.Component1 -eq 1) -and ([datetime]$_."Date/Time" -ge $(Get-Date "$((Get-Date).AddMonths(-1).Month)/1/$((Get-Date).AddMonths(-1).Year)"))) }
$NewCSV = $NewCSV | Foreach-Object { If ($_.Result -eq 1) { $_.Result = "Successful" } ElseIf ($_.Result -eq 2) { $_.Result = "Unsuccessful" } ; $_ }
$NewCSV = $NewCSV | Foreach-Object { If ($_."Update Method" -eq 2) { $_."Update Method" = "Scheduled Update" } ElseIf ($_."Update Method" = 4) { $_."Update Method" = "Control Manager" } ; $_ }
$NewCSV = $NewCSV | Foreach-Object { If ($_.Component1 -eq 1) { $_.Component1 = "Virus Pattern" } ; $_ }
$NewCSV = $NewCSV | Foreach-Object { $_ | Add-Member -MemberType NoteProperty -Name "Component" -Value "$($_.Component1) : $($_.Notes)" ; $_ }
$NewCSV = $NewCSV | Select "Date/Time","Result","Component","Update Method" | Sort-Object -Descending -Property "Date/Time" | Export-CSV "$($env:TEMP)\Server update log - $(Get-Date -Format 'MM.dd.yyyy').csv" -NoTypeInformation

Do {
                    Try {
                        $ErrorActionPreference = "Stop"
                        $i++
                        Send-MailMessage -From "$($env:COMPUTERNAME)@intrado.com" -To "doclibrary@sharepoint" -Attachments "$($env:TEMP)\Server update log - $(Get-Date -Format 'MM.dd.yyyy').csv" -Subject "CORP A/V Server Update Report" -SmtpServer $SMTPserver
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

Start-Sleep 300

# make monolithic server report
$Zones = ""
$Downloads = New-Item -ItemType Directory -Path "$($env:TEMP)\AuditDownloads" -Force
New-Item -ItemType File -Path "$($Env:temp)\OfficeScan client listing - ALL - Servers $(Get-Date -Format 'MM.dd.yyyy').csv" -Force | Out-Null
Foreach ($Zone in $Zones) {
    Try {
        $ErrorActionPreference = "Stop"
        $WebClient = New-Object System.Net.WebClient
        $WebClient.UseDefaultCredentials = $True
        $WebClient.DownloadFile("http://intradonet/sites/winauditcompliance/patches/Monthly%20Audit%20Reports%20AV%20and%20Patching/OfficeScan%20client%20listing%20-%20$($Zone)%20-%20Servers%20$(Get-Date -Format 'MM.dd.yyyy').csv","$($env:TEMP)\AuditDownloads\$($Zone).csv")
        $WebClient.Dispose()
        If (Get-Content "$($Env:temp)\OfficeScan client listing - ALL - Servers $(Get-Date -Format 'MM.dd.yyyy').csv") {
            Get-Content "$($env:TEMP)\AuditDownloads\$($Zone).csv" | Select -Skip 1| Out-File "$($Env:temp)\OfficeScan client listing - ALL - Servers $(Get-Date -Format 'MM.dd.yyyy').csv" -Append -Encoding utf8
            }
            Else {
                Get-Content "$($env:TEMP)\AuditDownloads\$($Zone).csv" | Out-File "$($Env:temp)\OfficeScan client listing - ALL - Servers $(Get-Date -Format 'MM.dd.yyyy').csv" -Append -Encoding utf8
                }
        }
        Catch {
            Write-Host $Error[0] -ForegroundColor Red
            }
        Finally {
            $ErrorActionPreference = "Continue"
            }
    }

Do {
                    Try {
                        $ErrorActionPreference = "Stop"
                        $i++
                        Send-MailMessage -From "$($env:COMPUTERNAME)@domain.com" -To "doclibrary@sharepoint" -Attachments "$($Env:temp)\OfficeScan client listing - ALL - Servers $(Get-Date -Format 'MM.dd.yyyy').csv" -Subject "CORP A/V All Server Report" -SmtpServer $SMTPserver
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
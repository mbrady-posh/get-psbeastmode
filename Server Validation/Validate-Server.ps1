Param(
    $Hostname,[bool]$local
    )

    If (!($Hostname)) {
        $Local = $True
        $Hostname = $(Get-wmiobject win32_computersystem) | Foreach-Object {$("$($_.name).$($_.domain)").ToUpper()}
        }

    $wmi = Get-Wmiobject win32_operatingsystem
    If ($local) {
        $wmi2 = $wmi
        }
        Else {
            $WMI2 = Get-WmiObject Win32_OperatingSystem -ComputerName $Hostname
            }
    $uptime = Get-Date $($wmi.ConvertToDateTime($WMI2.lastbootuptime))
    $downtime = (Get-EventLog -LogName System | Where {($_.source -eq "Microsoft-Windows-Kernel-General") -and ($_.EventID -eq "13")} | Select -first 1).TimeGenerated

    $script:scriptpath = split-path -parent $MyInvocation.MyCommand.Definition
    $SMTPserver = Get-Content "$($script:scriptpath)\smtpserver.txt"
    
    If (((Get-Date).AddMinutes(-8)) -lt $uptime) {
        Start-Sleep -Seconds 480
        }

        If ($local) {
            $BadServices = Get-WmiObject -Class Win32_Service | Where {(($_.StartMode -eq "Auto") -and ($_.State -ne "Running"))}
            }
            Else {
                $BadServices = Get-WmiObject -Class Win32_Service -ComputerName $Hostname | Where {(($_.StartMode -eq "Auto") -and ($_.State -ne "Running"))}
                }

        $WUSuccessLogs = @()
        $WUSuccessLogs += Get-EventLog -LogName System -After $((Get-Date $uptime).AddDays(-29)) -InstanceId 19

        $WUFailLogs = @()
        $WUFailLogs += Get-EventLog -LogName System -After $((Get-Date $uptime).AddDays(-29)) -InstanceId 20
    
        $BadLogs = @()
        If ($local) {
            $BadLogs += Get-EventLog -LogName Application -After $uptime -EntryType Error
            $BadLogs += Get-EventLog -LogName System -After $uptime -EntryType Error
            }
            Else {
                $BadLogs += Invoke-Command -usessl -Computername $Hostname -ArgumentList $uptime -ScriptBlock { Param($uptime) Get-EventLog -LogName Application -After $uptime -EntryType Error }
                $BadLogs += Invoke-Command -usessl -ComputerName $Hostname -ArgumentList $uptime -ScriptBlock {Param($uptime) Get-EventLog -LogName System -After $uptime -EntryType Error}
                }

        If($local) {
            $Shares = Get-WmiObject -Class Win32_Share | Select Name | Foreach-Object {$_.Name}
            }

        If (( (Get-ItemProperty -Path "HKLM:\Software\Microsoft\Exchange\Setup" -Name "MsiInstallPath" -ErrorAction SilentlyContinue).MsiInstallPath ) -or ((Get-ItemProperty -Path "HKLM:\Software\Microsoft\ExchangeServer\v14\Setup" -Name "MsiInstallPath" -ErrorAction SilentlyContinue).MsiInstallPath ) -or ((Get-ItemProperty -Path "HKLM:\Software\Microsoft\ExchangeServer\v15\Setup" -Name "MsiInstallPath" -ErrorAction SilentlyContinue).MsiInstallPath )) {
            $ExchangePresent = $True
            If ((Get-PSSnapin -Registered) -like "*Microsoft.Exchange.Management.PowerShell.E2010*") {
                Add-PSSnapin Microsoft.Exchange.Management.PowerShell.E2010
                }
                Else {
                    Add-PSSnapin Microsoft.Exchange.Management.Powershell.Admin
                    }
            $Queues = Get-MailboxServer | Where {$_.Name -ne "badserver"} | Get-Queue
            $BadQueues = $Queues | Where {$_.MessageCount -gt 5}

            $MailFlowTests = Foreach ($Server in $(Get-MailboxServer | Where {$_.Name -ne "badserver"})) { $Results = $Server | Test-Mailflow ; Add-Member -InputObject $Results -Name "ServerName" -Value $Server.Name -MemberType Noteproperty ; $Results }
            $FailedTests = $MailFlowTests | Where { ($_.TestMailflowResult -ne "Success") -or ($_.MessageLatencyTime -gt "00:00:05.0000000") }

            $FailedMAPITests = Foreach ($Server in $(Get-MailboxServer | Where {$_.Name -ne "badserver"})) { $Results = $Server | Test-MAPIConnectivity | Where {$_.Result -ne "Success" } }
            }

        If (Test-Path "C:\windows\system32\inetsrv\config\applicationhost.config" -ErrorAction SilentlyContinue) {
            $IISPresent = $True
            [xml]$IISConfig = Get-Content "C:\windows\system32\inetsrv\config\applicationhost.config"
            $IISSites = $IISConfig.configuration."system.applicationHost".sites.site
            $SiteObjArray = @()

            $SiteObjArray = Foreach ($Site in $IISSites) {
                $props = @{"SiteName"=$($Site.name);"Bindings"=$($Site.bindings.binding | Where {$_.protocol -like "http*"} | Foreach-Object { "$($_.protocol),$($_.bindingInformation)" }) }
                New-Object -TypeName PSCustomObject -Property $props
                }

            $WebResults = Foreach ($Site in $SiteObjArray) {
                Foreach ($binding in $Site.Bindings) {
                    $bindingarray = $binding -split ","
                    If ( ($bindingarray[1] -split ":")[2] -ne "") {
                        $hostbinding = ($bindingarray[1] -split ":")[2]
                        }
                        Else {
                            $hostbinding = "localhost"
                            }
                    $Port = ($bindingarray[1] -split ":")[1]
                    Try {
                        $WebRequest = New-Object System.Net.WebClient
                        $WebRequest.UseDefaultCredentials = $True
                        $WebRequest.OpenRead("$($bindingarray[0])://$($hostbinding):$($port)") | Out-Null
                        $Requestresult = New-Object -TypeName PSCustomObject -Property @{"Site"="$($bindingarray[0])://$($hostbinding):$($port)";"Code"="200 Success";"Status"="OK"}
                        }
                        Catch {
                            If ($_.Exception -like "*401*") {
                                $Requestresult = New-Object -TypeName PSCustomObject -Property @{"Site"="$($bindingarray[0])://$($hostbinding):$($port)";"Code"="401 Unauthorized";"Status"="Warning"}
                                }
                                ElseIf ($_.Exception -like "*404*") {
                                    $Requestresult = New-Object -TypeName PSCustomObject -Property @{"Site"="$($bindingarray[0])://$($hostbinding):$($port)";"Code"="404 Not Found";"Status"="Error"}
                                    }
                                ElseIf ($_.Exception -like "*500*") {
                                    $Requestresult = New-Object -TypeName PSCustomObject -Property @{"Site"="$($bindingarray[0])://$($hostbinding):$($port)";"Code"="500 Server Error";"Status"="Error"}
                                    }
                                ElseIf ($_.Exception -like "*403*") {
                                    $Requestresult = New-Object -TypeName PSCustomObject -Property @{"Site"="$($bindingarray[0])://$($hostbinding):$($port)";"Code"="403 Forbidden";"Status"="Warning"}
                                    }
                                ElseIf ($_.Exception -like "*Could not establish trust relationship for the SSL/TLS secure channel*") {
                                    $Requestresult = New-Object -TypeName PSCustomObject -Property @{"Site"="$($bindingarray[0])://$($hostbinding):$($port)";"Code"="HTTPS failure; self signed certificate? ";"Status"="Warning"}
                                    }
                                ElseIf ($_.Exception -like "*The remote name could not be resolved*") {
                                    $Requestresult = New-Object -TypeName PSCustomObject -Property @{"Site"="$($bindingarray[0])://$($hostbinding):$($port)";"Code"="DNS lookup failure";"Status"="Error"}
                                    }
                                Else {
                                    $Requestresult = New-Object -TypeName PSCustomObject -Property @{"Site"="$($bindingarray[0])://$($hostbinding):$($port)";"Code"="Other Error";"Status"="Error"}
                                    }
                               } 
                        Finally {
                            $Requestresult
                            $WebRequest.Dispose()
                            }
                    }
                }
            }

        $ValidationHTML = @'
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"><html xmlns="http://www.w3.org/1999/xhtml">
<head>
'@
        $ValidationHTML = "$($ValidationHTML)<title>$($Hostname)</title></head><body>"
        $ValidationHTML = "$($ValidationHTML)<h2>$($Hostname) Validation Results</h2>"
        $ValidationHTML = "$($ValidationHTML)<h3 style=`"color:red`">Down: $($downtime)</h3><h3 style=`"color:green`">Up: $($uptime)</h3>"
        $ValidationHTML = "$($ValidationHTML)<hr/><h3>Recent patch installation attempts</h3><div style=`"overflow:hidden`"><div style=`"width:50%;float:left`">"
        If ($WUSuccessLogs) {
            $ValidationHTML = "$($ValidationHTML)<p><strong>Windows Update successful installs</strong></p>"
            Foreach ($Success in $WUSuccessLogs) {
                $ValidationHTML = "$($ValidationHTML)<p style=`"color:green`">$($Success.TimeGenerated): $($Success.Message -split ":" | Select -Last 1)</p>"
                }
            }
            Else {
                $ValidationHTML = "$($ValidationHTML)<p>No Windows Update successes found.</p>"
                }
        $ValidationHTML = "$($ValidationHTML)</div><div style=`"width:50%;float:right`">"
        If ($WUFailLogs) {
            $ValidationHTML = "$($ValidationHTML)<p><strong>Windows Update failed installs</strong></p>"
            Foreach ($Fail in $WUFailLogs) {
                $ValidationHTML = "$($ValidationHTML)<p style=`"color:red`">$($Fail.TimeGenerated): $($Fail.Message -split ":" | Select -Last 1)</p>"
                }
            }
            Else {
                $ValidationHTML = "$($ValidationHTML)<p>No Windows Update failures found.</p>"
                }
        $ValidationHTML = "$($ValidationHTML)</div></div>"

        $ValidationHTML = "$($ValidationHTML)<hr/><h3>Service validation</h3>"
        If ($BadServices) {
            $ValidationHTML = "$($ValidationHTML)<table><tr><th>Name</th><th>Caption</th><th>Description</th><th>State</th></tr>"
            Foreach ($obj in $BadServices) {
                $ValidationHTML = "$($ValidationHTML)<tr><td>$($obj.Name)</td><td>$($obj.Caption)</td><td>$($obj.Description)</td><td>$($obj.State)</td></tr>"
                }
            $ValidationHTML = "$($ValidationHTML)</table>"
            }
            Else {
                $ValidationHTML = "$($ValidationHTML)<span style='color:green'>All services running.</span>"
                }
        $ValidationHTML = "$($ValidationHTML)<hr/><h3>Event Log validation</h3>"
        If ($BadLogs.Count -ne 0) {
            $ValidationHTML = "$($ValidationHTML)<table><tr><th>Time</th><th>Source</th><th>Message</th><th>State</th></tr>"
            Foreach ($obj in $BadLogs) {
                $ValidationHTML = "$($ValidationHTML)<tr><td>$($obj.TimeGenerated)</td><td>$($obj.Source)</td><td>$($obj.Message)</td></tr>"
                }
            $ValidationHTML = "$($ValidationHTML)</table>"
            }
            Else {
                $ValidationHTML = "$($ValidationHTML)<span style='color:green'>Application and System logs are clean.</span>"
                }
        $ValidationHTML = "$($ValidationHTML)<hr/><h3>File share validation</h3>"
        Foreach ($obj in $Shares) {
            $ValidationHTML = "$($ValidationHTML)<p style=`"color:green`">$($obj)</p>"
            }
        
        If ($ExchangePresent -eq $True) {
            $ValidationHTML = "$($ValidationHTML)<hr/><h3>Exchange validation</h3>"
            If ($BadQueues.Count -gt 0) {
                 $ValidationHTML = "$($ValidationHTML)<table><tr><th>Identity</th><th>DeliveryType</th><th>Status</th><th>MessageCount</th></tr>"
                Foreach ($obj in $BadQueues) {
                    $ValidationHTML = "$($ValidationHTML)<tr><td>$($obj.Identity)</td><td>$($obj.DeliveryType)</td><td>$($obj.Status)</td><td>$($obj.MessageCount)</td></tr>"
                    }
            $ValidationHTML = "$($ValidationHTML)</table>"
            }
            Else {
                $ValidationHTML = "$($ValidationHTML)<p style=`"color:green`">All $($Queues.Count) mail queues are clean.</p>"
                }
            If ($FailedTests.Count -gt 0) {
                $ValidationHTML = "$($ValidationHTML)<table><tr><th>ServerName</th><th>Test Result</th><th>Latency</th></tr>"
                Foreach ($obj in $FailedTests) {
                    $ValidationHTML = "$($ValidationHTML)<tr><td>$($obj.ServerName)</td><td>$($obj.TestMailflowResult)</td><td>$($obj.MessageLatencyTime)</td></tr>"
                    }
                $ValidationHTML = "$($ValidationHTML)</table>"
                }
                Else {
                    $ValidationHTML = "$($ValidationHTML)<p style=`"color:green`">Mail is flowing as expected across the $($MailFlowTests.Count) servers.</p>"
                    }
            If ($FailedMAPITests.Count -gt 0) {
                $ValidationHTML = "$($ValidationHTML)<table><tr><th>ServerName</th><th>Database</th><th>Result</th><th>Latency</th><th>Error</th></tr>"
                Foreach ($obj in $FailedMAPITests) {
                    $ValidationHTML = "$($ValidationHTML)<tr><td>$($obj.MailboxServer)</td><td>$($obj.Database)</td><td>$($obj.Result)</td><td>$($obj.Latency)</td><td>$($obj.Error)</td></tr>"
                    }
                $ValidationHTML = "$($ValidationHTML)</table>"
                }
                Else {
                    $ValidationHTML = "$($ValidationHTML)<p style=`"color:green`">All MAPI connectivity tests passed.</p>"
                    }
            }
        If ($IISPresent -eq $True) {
            $ValidationHTML = "$($ValidationHTML)<hr/><h3>IIS validation</h3>"
            If ($WebResults.Count -gt 0) {
                $ValidationHTML = "$($ValidationHTML)<table><tr><th>Binding</th><th>Return Code</th></tr>"
                Foreach ($obj in $WebResults) {
                    Switch ($obj.Status) { "Warning" { $Color = "Orange" } "Error" { $Color = "Red" } "OK" { $Color = "Green" } }
                    $ValidationHTML = "$($ValidationHTML)<tr><td style=`"color: $($Color)`">$($obj.Site)</td><td style=`"color: $($Color)`">$($obj.Code)</td></tr>"
                    }
                $ValidationHTML = "$($ValidationHTML)</table>"
                }
                Else {
                    $ValidationHTML = "$($ValidationHTML)<p style=`"color:green`">No sites to validate.</p>"
                    }
            }
        $ValidationHTML = "$($ValidationHTML)</body></html>"

        $OutFile = "$($env:TEMP)\$($Hostname).html"
        New-Item -ItemType File -Path $OutFile -Force | Out-Null
        $ValidationHTML | Out-File $OutFile -Force

                $i = 0
                Do {
                    Try {
                        $ErrorActionPreference = "Stop"
                        $i++
                        Send-MailMessage -From "$($env:COMPUTERNAME)@domain" -To "to@domain" -Attachments $OutFile -Subject $Hostname -SmtpServer $SMTPserver
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

& "$($script:scriptpath)\Get-PatchesWaiting.ps1"
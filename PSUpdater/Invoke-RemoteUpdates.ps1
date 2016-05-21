$script:scriptpath = split-path -parent $MyInvocation.MyCommand.Definition
Push-Location "C:\"

Function Set-ScriptVariables {
    [console]::TreatControlCAsInput = $True
    $script:serverlist = & "$script:scriptpath\get-patchlist.ps1"

    If ($script:serverlist -eq $null) {
        Pop-Location
        Exit 1
        }
    $script:skipped = 1
    $script:IDtoHostname = @{}
    $script:WaitforSync = 1
    $script:PatchLogDir = "$($env:USERPROFILE)\desktop\PatchLogs\$(Get-Date -Format 'MM-dd_HH-mm')"
    If (!(Test-Path $script:PatchLogDir)) {
        New-Item -ItemType Directory -Path "$script:PatchLogDir" | Out-Null
        }
    }

Function Set-Host {
    $Host.UI.RawUI.BackgroundColor = "Black"
    $host.UI.RawUI.ForegroundColor = "White"
    $NewSize = $host.UI.RawUI.WindowSize
    $NewSize.Width = 112 ; $host.ui.rawui.WindowSize = $NewSize
    $NewBSize = $host.ui.rawui.BufferSize
    $NewBSize.Width = 112 ; $host.ui.rawui.BufferSize = $NewBSize
    Clear-Host
    }

Function Test-HostList {
    $i = 0
    $script:Hostlist = New-Object System.Collections.ArrayList
    $Unreachable = @()
    Foreach ($HostName in $script:Serverlist) {
        $i++
        Write-Progress -Activity "Building final host list" -PercentComplete ($i / $Serverlist.count * 100) -CurrentOperation "$($Hostname)" -status "Testing connections"
        $Testsession = New-PSSession -UseSSL $HostName -ErrorAction SilentlyContinue -Credential (Select-Credentials $HostName)
        If ($Testsession) {
            $script:Hostlist.Add("$Hostname") | Out-Null
            }
            Else {
                $Unreachable += $HostName
                }
        $ErrorActionPreference = "SilentlyContinue"
        Remove-PSSession $Testsession
        $ErrorActionPreference = "Continue"
        }
    Write-Progress -Activity "Building final host list" -Status "Ready" -Completed
    If ($Unreachable.Count -ge 1) {
        Foreach ($server in $Unreachable) {
            Write-Host -ForegroundColor Red $server
            }
        $Response = Read-Host -Prompt "These hosts could not be contacted, abort? Y/N"
        If ($Response -eq "n") {
            #do nothing
            }
            Else {
                Pop-Location
                Exit 1
                }
        }
    }

Function Gather-Credentials {
    $script:ZoneCreds = @{}
    $domains = @()
    Foreach ($Hostname in $script:Serverlist) {
        $domains += ($Hostname.Split(".")[1]).ToUpper()
        }
    If ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -notlike "*-admin") {
        $script:ZoneCreds += @{"domain"=$(Get-Credential -Message "domain Admin Credentials" -UserName "domain\$(([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -Split "\\")[1])-admin")}
        }
        Else {
            $script:ZoneCreds += @{"domain"=$(Get-Credential -Message "domain Admin Credentials" -UserName "domain\$(([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -Split "\\")[1])")}
            }
    Foreach ($domain in ($domains | Select -Unique)) {
        If ($domain -in @("domain","UNIX","test")) {
            # Do nothing
            }
            Else {
                If ([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -notlike "*-admin") {
                    $script:ZoneCreds += @{"$Domain"=$(Get-Credential -Message "$Domain Admin Credentials" -UserName "$($Domain).domain.pri\$(([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -Split "\\")[1])-admin")}
                    }
                    Else {
                        $script:ZoneCreds += @{"$Domain"=$(Get-Credential -Message "$Domain Admin Credentials" -UserName "$($Domain).domain.pri\$(([System.Security.Principal.WindowsIdentity]::GetCurrent().Name -Split "\\")[1])")}
                        }
                }
        }
    }

Function Select-Credentials($HostName) {
    If ($(($Hostname.Split("."))[1]) -like "domain") {
        Get-Credential $($script:ZoneCreds.domain)
        }
        ElseIf ($(($Hostname.Split("."))[1]) -like "other") {
            Get-Credential $($script:ZoneCreds.domain)
            }
        Else {
            Get-Credential $($Script:ZoneCreds."$($Hostname.Split(".")[1])")
            }
    }

Function Run-UpdateHost {
    $i = 0
    Foreach ($Hostname in $script:hostlist) {
        $i++
        $script:IDtoHostname += @{$($i)=$($Hostname)}
        }
    
    $cursor = 4 + $($script:hostlist.Count)
     Do {
        If ($script:WaitforSync -eq 1) {
            Do {
                Write-Progress -Activity "Waiting for first sync" -PercentComplete 100
                Start-Sleep -Milliseconds 250
                $Serverobj = Receive-Job $script:UpdateJob | Select -Last 1
                }
                While ($Serverobj -eq $null)
            Write-Progress -Activity "Waiting for first sync" -Completed
            $script:WaitforSync = 0
            }
            Else {
                $Joboutput = Receive-Job $script:UpdateJob -ErrorAction SilentlyContinue | Select -Last 1
                If ($Joboutput -ne $null) {
                    $Serverobj = $Joboutput
                    $Joboutput = $null
                    }
                }

        Clear-Host
        Write-Host -ForegroundColor Cyan "---------------------------------------------------------------------------------------------------------------"
        Write-Host -ForegroundColor Cyan "****************************************domain Windows Update Console*****************************************"
        Write-Host -ForegroundColor Cyan "---------------------------------------------------------------------------------------------------------------"
        Write-Host "ID`tHost Name`t`t`tStatus`t`t`tLast WU Log Update`tLast Startup"
        If ([math]::abs((-$($script:hostlist.count) - 4)+$($cursor)) -eq 0) {
            Write-Host "0`tAll servers" -ForegroundColor Blue -BackgroundColor White
            }
            Else {
                Write-Host "0`tAll servers" -ForegroundColor Blue
                }
        Foreach ($Hostname in $script:hostlist) {
            If (((-$($script:hostlist.count) - 4)+$($cursor)) -eq -$($Serverobj.$($Hostname).id)) {
                 Write-Host "$($Serverobj.$($Hostname).id)`t$($Hostname)$($Status)`t$($Serverobj.$($Hostname).log.lasteventid)`t$($Serverobj.$($Hostname).log.lastupdate)`t$($Serverobj.$($Hostname).log.laststartup)" -ForegroundColor $($Serverobj.$($Hostname).log.color) -BackgroundColor White
                 }
                 Else {
                    Write-Host "$($Serverobj.$($Hostname).id)`t$($Hostname)$($Status)`t$($Serverobj.$($Hostname).log.lasteventid)`t$($Serverobj.$($Hostname).log.lastupdate)`t$($Serverobj.$($Hostname).log.laststartup)" -ForegroundColor $($Serverobj.$($Hostname).log.color)
                    }
            }
        Write-Host -ForegroundColor Cyan "---------------------------------------------------------------------------------------------------------------"
        Write-Host -ForegroundColor Cyan "| l : view log | d : download patches | p : install patches | r : reboot | v : validate | q : quit | h : help |"
        Write-Host -ForegroundColor Cyan "---------------------------------------------------------------------------------------------------------------"
        ""

        $cursorposition = $host.ui.RawUI.CursorPosition
        $Cursorposition.Y = $cursorposition.Y - $cursor
        $host.UI.RawUI.CursorPosition = $cursorposition
        $key = $null
        $key = $host.ui.rawui.ReadKey("NoEcho,IncludeKeyDown")
        If ($key.VirtualKeyCode -eq "38") {
             If (((-$($script:hostlist.count) - 4)+$($cursor+1)) -in -$($script:hostlist.count)..0) {
                $cursor++
                }
             }
             ElseIf ($key.VirtualKeyCode -eq "40") {
                If (((-$($script:hostlist.count) - 4)+$($cursor-1)) -in -$($script:hostlist.count)..0) {
                    $cursor = $cursor - 1
                    }
                }
              ElseIf ($key.character -eq "h") {
                #do help
                # Clear-Host
                # Write-Host "Help stuff"
                }
              ElseIf ($key.character -eq "r") {
                Clear-Host
                $Choices = @("Y","N")
                If ($([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -eq 0) {
                    $Message = "`nAre you sure you want to reboot all servers?"
                    }
                    Else {
                        $Message = "`nAre you sure you want to reboot $($script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))))?"
                        }
                $Title = ""
                $DefaultChoice = 1
                [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
                Foreach ($Possible in $Poss) {            
		            New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
	                }       
	             $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                 If ($Answer -eq 0) {
                    If ($([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -eq 0) {
                        $script:hostlist | Foreach-Object {Invoke-Command -UseSSL -ComputerName $_ -Credential (Select-Credentials $_)  -ScriptBlock {Write-EventLog  -LogName PSUpdater -Source "PSUpdater_Client" -EntryType Information -EventId "6" -Message "Rebooting system now." ; Restart-Computer -Force } }
                        }
                        Else {
                            Invoke-Command -UseSSL -Computername $script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -Credential (Select-Credentials $($script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))))) -ScriptBlock {Write-EventLog  -LogName PSUpdater -Source "PSUpdater_Client" -EntryType Information -EventId "6" -Message "Rebooting system now." ; Restart-Computer -Force}
                            }
                    }
                }
              ElseIf ($key.character -eq "v") {
                Clear-Host
                $Choices = @("Y","N")
                If ($([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -eq 0) {
                    $key = $null
                    }
                    Else {
                        $Message = "`nAre you sure you want to validate $($script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))))?"
                        $Title = ""
                        $DefaultChoice = 1
                        [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
                        Foreach ($Possible in $Poss) {            
		                    New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
	                        }       
	                     $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                         If ($Answer -eq 0) {
                            Validate-PatchedServer -Hostname "$($script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))))" -ZoneCreds $($script:ZoneCreds) -OutputPath "$($script:PatchLogDir)\$($script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))))"
                            }
                            Else {
                                $key = $null
                                }
                        }
              }
              ElseIf ($key.character -eq "q") {
                Clear-Host
                $Choices = @("Y","N")
                $Message = "`nAre you sure you want to exit?"
                $Title = ""
                $DefaultChoice = 1
                [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
                Foreach ($Possible in $Poss) {            
		            New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
	                }       
	             $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                 If ($Answer -eq 0) {
                    Clear-Host
                    Get-Job | Remove-Job -Force
                    Break
                    }
                    Else {
                        $key = $null
                        }
                }
              ElseIf ($key.character -eq "d") {
                    Clear-Host
                    $Choices = @("Y","N")
                    If ($([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -eq 0) {
                        $Message = "`nAre you sure you want to download patches on all servers?"
                        }
                        Else {
                            $Message = "`nAre you sure you want to download patches on $($script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))))?"
                            }
                    $Title = ""
                    $DefaultChoice = 1
                    [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
                    Foreach ($Possible in $Poss) {            
		                New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
	                    }       
	                 $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                     If ($Answer -eq 0) {
                        If ($([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -eq 0) {
                            $script:hostlist | Foreach-Object { Invoke-Command -UseSSL -Computername $_ -Credential (Select-Credentials $_) -ScriptBlock { Start-Process "schtasks.exe" "/Run /TN domain\PSUpdater_Download"} }
                            }
                            Else {
                                Invoke-Command -UseSSL -Computername $script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -Credential (Select-Credentials $script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor)))) -ScriptBlock { Start-Process "schtasks.exe" "/Run /TN domain\PSUpdater_Download"}
                                }
                        }
                        Else {
                            $key = $null
                            }
                }
                ElseIf ($key.character -eq "p") {
                    Clear-Host
                    $Choices = @("Y","N")
                    If ($([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -eq 0) {
                        $Message = "`nAre you sure you want to begin patching all servers?"
                        }
                        Else {
                            $Message = "`nAre you sure you want to begin patching $($script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))))?"
                            }
                    $Title = ""
                    $DefaultChoice = 1
                    [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
                    Foreach ($Possible in $Poss) {            
		                New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
	                    }       
	                 $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                     If ($Answer -eq 0) {
                        If ($([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -eq 0) {
                            $script:hostlist | Foreach-Object { Invoke-Command -UseSSL -Computername $_ -Credential (Select-Credentials $_) -ScriptBlock { Start-Process "schtasks.exe" "/Run /TN domain\PSUpdater_Install"} }
                            }
                            Else {
                                Invoke-Command -UseSSL -Computername $script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -Credential (Select-Credentials $script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor)))) -ScriptBlock { Start-Process "schtasks.exe" "/Run /TN domain\PSUpdater_Install"}
                                }
                        }
                        Else {
                            $key = $null
                            }
                }
                ElseIf ($key.character -eq "l") {
                    Clear-Host
                    If ($([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -eq 0) {
                        $Choices = @("Y","N")
                        $Message = "`nAre you sure you want to open log windows for all servers?"
                        $Title = ""
                        $DefaultChoice = 1
                        [System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
                        Foreach ($Possible in $Poss) {            
		                    New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
	                        }       
	                     $Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 
                         If ($Answer -eq 0) {
                            If ($([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))) -eq 0) {
                                $script:hostlist | Foreach-Object { Start-Process "powershell.exe" "$($script:scriptpath)\process-wulog.ps1 -HostName $($_) -FileName `"$($Script:PatchLogDir)\$($Hostname).log`"" }
                                }
                            }
                        }
                        Else {
                                    Start-Process "powershell.exe" "$($script:scriptpath)\process-wulog.ps1 -Hostname `"$($script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor))))`" -FileName `"$($script:PatchLogDir)\$($script:IDtoHostname.$([math]::abs((-$($script:hostlist.count) - 4)+$($cursor)))).log`""
                                    }
                    }
                Start-sleep -Milliseconds 500
        } 
        While ($True -eq $true)
    }

Function Validate-PatchedServer {
    
    Param(
    $Hostname, $ZoneCreds, $OutputPath
    )

    Function Select-Credentials($HostName) {
        If ($(($Hostname.Split("."))[1]) -like "domain") {
            Get-Credential $($ZoneCreds.domain)
            }
            ElseIf ($(($Hostname.Split("."))[1]) -like "UNIX") {
                Get-Credential $($ZoneCreds.domain)
                }
            Else {
                Get-Credential $($ZoneCreds."$($Hostname.Split(".")[1])")
                }
        }
    $Creds = Select-Credentials $Hostname
    $ValidationJob = Start-Job -ArgumentList $Hostname,$Creds,$Reboottime, $OutputPath -ScriptBlock {
        Param ($Hostname,$Creds,$Reboottime, $OutputPath)
        $script:scriptpath = split-path -parent $MyInvocation.MyCommand.Definition

        $BadServices = Invoke-command -UseSSL -Computername $Hostname -Credential  ($Creds) -ScriptBlock {Get-WmiObject -Class Win32_Service | Where {(($_.StartMode -eq "Auto") -and ($_.State -ne "Running"))} }
        
        $wmi = Invoke-Command -UseSSL -Computername $Hostname -Credential $Creds -ScriptBlock { Get-wmiobject Win32_OperatingSystem }
        $wmi2 = Get-WmiObject Win32_Operatingsystem
        $Reboottime = $wmi2.ConvertToDateTime($wmi.LastBootupTime)
        $BadLogs = @()
        $BadLogs += Invoke-command -UseSSL -Computername $Hostname -Credential  $Creds -ArgumentList $reboottime -ScriptBlock {Param($Reboottime) Get-EventLog -LogName Application -After $reboottime -EntryType Error}
        $BadLogs += Invoke-command -UseSSL -Computername $Hostname -Credential  $Creds -ArgumentList $Reboottime -ScriptBlock {Param($reboottime) Get-EventLog -LogName System -After $reboottime  -EntryType Error}

        If (Test-Path "$($script:scriptpath)\$($Hostname)_validate.csv") {
            $ExtraValidation = New-Object PSCustomObject
            $Validationcsv = Import-Csv "$($script:scriptpath)\$($Hostname)_validate.csv"
            Foreach ($item in $Extravalidation) {
                Add-Member -InputObject $ExtraValidation -MemberType NoteProperty -Name $($item.Name) -Value $($item.Command)
                }
             }

        If ($ExtraValidation) {
            Foreach ($val in $ExtraValidation) {
                Invoke-Expression $val.Command
                }
            }
        $ValidationHTML = @'
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN"  "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd"><html xmlns="http://www.w3.org/1999/xhtml">
<head>
'@
        $ValidationHTML = "$($ValidationHTML)<title>$($Hostname) Validation Results</title></head><body>"
        $ValidationHTML = "$($ValidationHTML)<h2>$($Hostname) Validation Results</h2>"
        $ValidationHTML = "$($ValidationHTML)<h3>Service validation</h3><hr/>"
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
        $ValidationHTML = "$($ValidationHTML)<h3>Event Log validation</h3>"
        If ($BadLogs) {
            $ValidationHTML = "$($ValidationHTML)<table><tr><th>Time</th><th>Source</th><th>Message</th><th>State</th></tr>"
            Foreach ($obj in $BadLogs) {
                $ValidationHTML = "$($ValidationHTML)<tr><td>$($obj.TimeGenerated)</td><td>$($obj.Source)</td><td>$($obj.Message)</td></tr>"
                }
            $ValidationHTML = "$($ValidationHTML)</table>"
            }
            Else {
                $ValidationHTML = "$($ValidationHTML)<span style='color:green'>Application and System logs are clean.</span>"
                }
        $ValidationHTML = "$($ValidationHTML)</body></html>"
        $ValidationHTML | Out-File "$($OutputPath).html" -Force
        Start-Process "iexplore.exe" "file://$($OutputPath).html"
        }
    }

Set-ScriptVariables
Set-Host
Gather-Credentials
Test-Hostlist

$script:UpdateJob = Start-Job -ArgumentList ($script:Hostlist,$script:IDtoHostname,$script:ZoneCreds,$script:PatchLogDir) -ScriptBlock {
            Param(
                $Hostlist,
                $IDtoHostname,
                $ZoneCreds,
                $PatchLogDir
                ) 
            Function Select-Credentials($HostName) {
                If ($(($Hostname.Split("."))[1]) -like "domain") {
                    Get-Credential $($ZoneCreds.domain)
                    }
                    ElseIf ($(($Hostname.Split("."))[1]) -like "UNIX") {
                        Get-Credential $($ZoneCreds.domain)
                        }
                    Else {
                        Get-Credential $($ZoneCreds.$($Hostname.Split(".")[1]))
                        }
                }
            $Serverobj = New-Object PSCustomObject
            $i = 0
            Foreach ($Hostname in $hostlist) {
                $i++
                $props = @{"ID"=$i;"Log"=(New-Object -TypeName PSCustomObject);"StartTime"=(Get-Date -Format "yyyy-MM-dd HH:mm:ss")}
                Add-Member -InputObject $Serverobj -MemberType NoteProperty -Name $Hostname -Value $(New-Object PSCustomObject -Property $props)
                } 
            Do { 
                Foreach ($Hostname in $hostlist) {
                    $FileName = "C:\windows\windowsupdate.log"
                    If (!(Test-Path "$($PatchLogDir)\$($Hostname).log")) {
                        New-Item "$($PatchLogDir)\$($Hostname).log" -ItemType File | Out-Null
                        }
                    $LocalLog = "$($PatchLogDir)\$($Hostname).log"

                $HostLog = Invoke-Command -UseSSL -Computername $Hostname -ArgumentList $FileName,$Serverobj,$Hostname -ScriptBlock {
                        Param($FileName,$Serverobj,$Hostname) 
                        $text = Get-Content $FileName -ReadCount 0
                        If ($($Serverobj.$($Hostname).log.LogIndex) -eq $null) {
                            $StartDateobj = (Get-Date $($Serverobj.$($Hostname).StartTime)).AddHours(-2)
                            $ErrorActionPreference = "SilentlyContinue"
                            If ($(Get-Date "$(($_ -Split `"`t`")[0]) $(((($_ -Split `"`t`")[1])  -Split ':' | Select -First 3) -Join ':')") -gt $StartDateobj) {
                                $logIndex = Foreach ($item in $text) { If ($(Get-Date "$(($_ -Split `"`t`")[0]) $(((($_ -Split `"`t`")[1])  -Split ':' | Select -First 3) -Join ':')") -gt $StartDateobj) { $_ ; Break } }
                                }
                                Else {
                                    $LogIndex = $null
                                    }
                            }
                            Else { $LogIndex = $($Serverobj.$($Hostname).log.LogIndex) }
                        $ErrorActionPreference = "Continue"
                        If ($LogIndex -ne $null) {
                            $firstline = ($text | Select-String -Pattern $LogIndex -SimpleMatch).LineNumber
                            }
                        If ($LogIndex -eq $null) {
                            $NumberofLines = 10
                            }
                            Else {
                                $NumberofLines = ($text.Count - $firstline)
                                }
                        Return $(New-Object PSCustomObject -Property @{"Log"=$($text | Select -Last $NumberofLines);"LogIndex"=$($text | Select -Last 1) })
                        } -Credential (Select-Credentials $Hostname)
                    
                    If ($HostLog.Log -like "[0-9]*") {
                        $HostLog.Log | Add-Content $LocalLog
                        }

                    $LastLog = (Get-Content $LocalLog -Last 1) -Split "`t"
                    Add-Member -MemberType NoteProperty -InputObject $($Serverobj.$($Hostname).log) -Name "LastUpdate" -Value "$(Get-Date `"$($LastLog[0]) $($($Lastlog[1] -split `":`" | Select -First 3) -Join `":`")`")" -Force
                    If ($HostLog.LogIndex -ne $null) {
                        Add-Member -MemberType NoteProperty -InputObject $($Serverobj.$($Hostname).log) -Name "LogIndex" -Value $($HostLog.LogIndex) -Force
                        }
                    $LastEvent = Invoke-Command -UseSSL -ComputerName $Hostname -ArgumentList $Hostname -ScriptBlock { Param($Hostname) (Get-EventLog -LogName PSUpdater | Sort-Object -Property TimeGenerated | Select -Last 1) ;  } -Credential (Select-Credentials $Hostname) -ErrorAction SilentlyContinue
                    #$LastEvent = Invoke-Command -UseSSL -Computername $Hostname -ArgumentList $Hostname -ScriptBlock { Param($Hostname) (Get-WinEvent -LogName PSUpdater -MaxEvents 1) ;  } -Credential (Select-Credentials $Hostname) -ErrorAction SilentlyContinue
                    $LastStartup = Invoke-Command -UseSSL -Computername $Hostname -ArgumentList $Hostname -ScriptBlock { Param($Hostname) $WMI = Get-WmiObject Win32_OperatingSystem ; Get-Date $($wmi.ConvertToDateTime($WMI.lastbootuptime)) -Format "MM/dd HH:mm:ss" } -Credential (Select-Credentials $Hostname) -ErrorAction SilentlyContinue
                    $LastEventID = $LastEvent.EventID
                    $LastEventTime = $LastEvent.TimeGenerated
                    $LastEventMsg = $LastEvent.Message
                    If (!($LastEventID)) { $LastEventID = "" }
                    Switch ($LastEventID) { 1 {  $LastEventText = "No updates needed    "; $EventColor = "DarkGreen" } 2 { $LastEventText = "Gathering update list"; $EventColor = "DarkGreen" } 3 { $LastEventText = "Installing updates   "; $EventColor = "DarkGreen" } 4 { $LastEventText = "Pending reboot       "; $EventColor = "DarkBlue" } 5 { $LastEventText = "Ready to validate    "; $EventColor = "DarkBlue" } 6 { $LastEventText = "Ready to validate    "; $EventColor = "DarkBlue" } 7 {  $LastEventText = " $(($LastEventMsg -Split " ")[0]) updates needed    "; $EventColor = "DarkGreen" } default { $LastEventText = "No data             "; $EventColor = "Red" } }
                    Add-Member -MemberType NoteProperty -InputObject $($Serverobj.$($Hostname).log) -Name "LastEventID" -Value $LastEventText -Force
                    Add-Member -MemberType NoteProperty -InputObject $($Serverobj.$($Hostname).log) -Name "Color" -Value $EventColor -Force
                    Add-Member -MemberType NoteProperty -InputObject $($Serverobj.$($Hostname).log) -Name "LastEventTime" -Value $LastEventTime -Force
                    Add-Member -MemberType NoteProperty -InputObject $($Serverobj.$($Hostname).log) -Name "LastEventMsg" -Value $LastEventMsg -Force
                    Add-Member -MemberType NoteProperty -InputObject $($Serverobj.$($Hostname).log) -Name "LastStartup" -Value $LastStartup -Force
                    $EventColor = $null
                    $LastEventID = $null
                    $LastEventText = $null
                    $LastEventTime = $null
                    $HostLog = $null
                    } 
                $Serverobj
                } 
                While ($True -eq $True)
    } 

Run-UpdateHost
Pop-Location
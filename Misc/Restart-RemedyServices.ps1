$arserver = ""
$midtierserver = ""
$ssoserver = ""

$Choices = @("Y","N")
$Message = "`nAre you sure you want to restart Remedy services?"
$Title = ""
$DefaultChoice = 1
[System.Management.Automation.Host.ChoiceDescription[]]$Poss = $Choices
Foreach ($Possible in $Poss) {            
    New-Object System.Management.Automation.Host.ChoiceDescription "&$($Possible)", "Sets $Possible as an answer." | Out-Null
    }       
$Answer = $Host.UI.PromptForChoice( $Title, $Message, $Poss, $DefaultChoice ) 

If ($Answer -eq "1") {
    Exit 1
    }

 If ($(Get-EventLog -LogName "RemedyRestart" -ErrorAction SilentlyContinue) -eq $null) {
            If ([System.Diagnostics.EventLog]::SourceExists("RemedyRestart_Client") -eq $false) {
                [System.Diagnostics.EventLog]::CreateEventSource("RemedyRestart_Client", "PSUpdater")
                }
            New-EventLog -LogName "RemedyRestart" -Source "RemedyRestart_Client"
            }
            ElseIf ([System.Diagnostics.EventLog]::SourceExists("RemedyRestart_Client") -eq $false) {
                [System.Diagnostics.EventLog]::CreateEventSource("RemedyRestart_Client", "RemedyRestart")
                }

Try {
    Write-Progress -PercentComplete $((1/6)*100) -Activity "Restarting Remedy services" -CurrentOperation "Stopping Mid-Tier service" -Status "Processing"
    $service = Get-WmiObject -ComputerName $midtierserver -Class Win32_Service | Where-Object {$_.Name -eq "tomcat7"}
    $Service.StopService() | Out-Null
    Do {
        Start-Sleep -Seconds 5
        }
        Until ( (Get-WmiObject -ComputerName $midtierserver -Class Win32_Service | Where-Object {$_.Name -eq "tomcat7"}).State -eq "Stopped")
    }
    Catch {
        Write-EventLog -Source "RemedyRestart_Client" -EventId 0 -LogName "RemedyRestart" -Message "The Mid-Tier service could not be stopped. Please investigate further." -EntryType Error
        Exit 1
        }
    Finally {
        $Service = $null
        }

Try {
    Write-Progress -PercentComplete $((2/6)*100) -Activity "Restarting Remedy services" -CurrentOperation "Stopping AR service" -Status "Processing"
    $service = Get-WmiObject -ComputerName $arserver -Class Win32_Service | Where-Object {$_.Name -eq "BMC Remedy Action Request System Server LMV08-REMAPPQA"}
    $Service.StopService() | Out-Null
    Do {
        Start-Sleep -Seconds 5
        }
        Until ((Get-WmiObject -ComputerName $arserver -Class Win32_Service | Where-Object {$_.Name -eq "BMC Remedy Action Request System Server LMV08-REMAPPQA"}).State -eq "Stopped")
    }
    Catch {
        Write-EventLog -Source "RemedyRestart_Client" -EventId 0 -LogName "RemedyRestart" -EntryType Error -Message "The AR service could not be stopped. Please investigate further."
        Exit 1
        }
    Finally {
        $Service = $null
        }

Try {
    Write-Progress -PercentComplete $((3/6)*100) -Activity "Restarting Remedy services" -CurrentOperation "Stopping SSO service" -Status "Processing"
    $service = Get-WmiObject -ComputerName $ssoserver -Class Win32_Service | Where-Object {$_.Name -eq "BMCAtriumSSOTomcat"}
    $Service.StopService() | Out-Null
    Do {
        Start-Sleep -Seconds 5
        }
        Until ((Get-WmiObject -ComputerName $ssoserver -Class Win32_Service | Where-Object {$_.Name -eq "BMCAtriumSSOTomcat"}).State -eq "Stopped")
    }
    Catch {
        Write-EventLog -Source "RemedyRestart_Client" -EventId 0 -LogName "RemedyRestart" -EntryType Error -Message "The SSO service could not be stopped. Please investigate further."
        Exit 1
        }
    Finally {
        $Service = $null
        }

Try {
    Write-Progress -PercentComplete $((4/6)*100) -Activity "Restarting Remedy services" -CurrentOperation "Starting SSO service" -Status "Processing"
    $service = Get-WmiObject -ComputerName $ssoserver -Class Win32_Service | Where-Object {$_.Name -eq "BMCAtriumSSOTomcat"}
    $Service.StartService() | Out-Null
    Do {
        Start-Sleep -Seconds 5
        }
        Until ((Get-WmiObject -ComputerName $ssoserver -Class Win32_Service | Where-Object {$_.Name -eq "BMCAtriumSSOTomcat"}).State -eq "Running")
    }
    Catch {
        Write-EventLog -Source "RemedyRestart_Client" -EventId 0 -LogName "RemedyRestart" -EntryType Error -Message "The SSO service could not be started. Please investigate further."
        Exit 1
        }
    Finally {
        $Service = $null
        }

Try {
    Write-Progress -PercentComplete $((5/6)*100) -Activity "Restarting Remedy services" -CurrentOperation "Starting AR service" -Status "Processing"
    $service = Get-WmiObject -ComputerName $arserver -Class Win32_Service | Where-Object {$_.Name -eq "BMC Remedy Action Request System Server LMV08-REMAPPQA"}
    $Service.StartService() | Out-Null
    Do {
        Start-Sleep -Seconds 5
        }
        Until ((Get-WmiObject -ComputerName $arserver -Class Win32_Service | Where-Object {$_.Name -eq "BMC Remedy Action Request System Server LMV08-REMAPPQA"}).State -eq "Running")
    }
    Catch {
        Write-EventLog -Source "RemedyRestart_Client" -EventId 0 -LogName "RemedyRestart" -EntryType Error -Message "The AR service could not be started. Please investigate further."
        Exit 1
        }
    Finally {
        $Service = $null
        }

Try {
    Write-Progress -PercentComplete $((6/6)*100) -Activity "Restarting Remedy services" -CurrentOperation "Starting Mid-Tier service" -Status "Processing"
    $service = Get-WmiObject -ComputerName $midtierserver -Class Win32_Service | Where-Object {$_.Name -eq "tomcat7"}
    $Service.StartService() | Out-Null
    Do {
        Start-Sleep -Seconds 5
        }
        Until ((Get-WmiObject -ComputerName $midtierserver -Class Win32_Service | Where-Object {$_.Name -eq "tomcat7"}).State -eq "Running")
    }
    Catch {
        Write-EventLog -Source "RemedyRestart_Client" -EventId 0 -LogName "RemedyRestart" -EntryType Error -Message "The Mid-Tier service could not be started. Please investigate further."
        Exit 1
        }
    Finally {
        $Service = $null
        }
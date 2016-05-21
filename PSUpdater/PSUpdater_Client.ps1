Param(
    [Parameter(Mandatory=$True)][bool]$DownloadOnly
    )

If ($DownloadOnly -eq $True) {
    If ($(Get-EventLog -LogName "PSUpdater" -ErrorAction SilentlyContinue) -eq $null) {
            If ([System.Diagnostics.EventLog]::SourceExists("PSUpdater_Client") -eq $false) {
                [System.Diagnostics.EventLog]::CreateEventSource("PSUpdater_Client", "PSUpdater")
                }
            New-EventLog -LogName "PSUpdater" -Source "PSUpdater_Client"
            }
            ElseIf ([System.Diagnostics.EventLog]::SourceExists("PSUpdater_Client") -eq $false) {
                [System.Diagnostics.EventLog]::CreateEventSource("PSUpdater_Client", "PSUpdater")
                }
    $UpdateSession = New-Object -ComObject Microsoft.Update.Session
    $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
    $UpdateResults = $UpdateSearcher.Search(" IsAssigned=1 and IsHidden=0 and IsInstalled=0 and Type='Software'")
    (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
    If ($UpdateResults.Updates.Count -eq 0) {
                Write-EventLog -LogName PSUpdater -Source "PSUpdater_Client" -EntryType Information -EventId "1" -Message "There are no updates to apply. Exiting."
                Exit 0
                }
                Else {
                    $UpdatestoDownload = New-Object -ComObject Microsoft.Update.Updatecoll
                    Foreach ($Update in $UpdateResults.Updates) {
                        If ($Update.IsDownloaded -eq $False) {
                            $UpdatestoDownload.Add($Update)
                            }
                        }
                    $UpdatestoDownload.Download()
                    $UpdatestoInstall = New-Object -ComObject Microsoft.Update.Updatecoll
                    Foreach ($Update in $UpdateResults.Updates) {
                        If ($Update.IsDownloaded -eq $True) {
                            $UpdatestoInstall.Add($Update) | Out-Null
                            }
                        }
                    Write-EventLog -LogName PSUpdater -Source "PSUpdater_Client" -EntryType Information -EventId "7" -Message "$(($UpdatestoInstall).Count) updates to install."
                    }
    }
    Else {
         If ($(Get-EventLog -LogName "PSUpdater" -ErrorAction SilentlyContinue) -eq $null) {
            If ([System.Diagnostics.EventLog]::SourceExists("PSUpdater_Client") -eq $false) {
                [System.Diagnostics.EventLog]::CreateEventSource("PSUpdater_Client", "PSUpdater")
                }
            New-EventLog -LogName "PSUpdater" -Source "PSUpdater_Client"
            }
            ElseIf ([System.Diagnostics.EventLog]::SourceExists("PSUpdater_Client") -eq $false) {
                [System.Diagnostics.EventLog]::CreateEventSource("PSUpdater_Client", "PSUpdater")
                }

        $UpdateSession = New-Object -ComObject Microsoft.Update.Session
            $UpdateSearcher = $UpdateSession.CreateUpdateSearcher()
            $UpdateResults = $UpdateSearcher.Search(" IsAssigned=1 and IsHidden=0 and IsInstalled=0 and Type='Software'")
            (New-Object -ComObject Microsoft.Update.AutoUpdate).DetectNow()
            If ($UpdateResults.Updates.Count -eq 0) {
                Write-EventLog -LogName PSUpdater -Source "PSUpdater_Client" -EntryType Information -EventId "1" -Message "There are no updates to apply. Exiting."
                Exit 0
                }
                Else {
                    $UpdatestoDownload = New-Object -ComObject Microsoft.Update.Updatecoll
                    $UpdatestoInstall = New-Object -ComObject Microsoft.Update.Updatecoll
                    Foreach ($Update in $UpdateResults.Updates) {
                        If ($Update.IsDownloaded -eq $True) {
                            $UpdatestoInstall.Add($Update) | Out-Null
                            }
                        }
                    Write-EventLog  -LogName PSUpdater -Source "PSUpdater_Client" -EntryType Information -EventId "2" -Message "Updates to apply: $($Updatestoinstall | Foreach-Object { Write-Output "KB$(((($_.Title) -Split 'KB')[1]) -Replace ".$")" })"
                    $UpdateInstaller = $UpdateSession.CreateUpdateInstaller()
                    $UpdateInstaller.Updates = $UpdatestoInstall
                    Write-EventLog  -LogName PSUpdater -Source "PSUpdater_Client" -EntryType Information -EventId "3" -Message "Installing updates now."
                    $Result = $UpdateInstaller.Install()
                    If ($Result.RebootRequired -eq $True) {
                        Write-EventLog  -LogName PSUpdater -Source "PSUpdater_Client" -EntryType Warning -EventId "4" -Message "Update installation complete, but a reboot is required."
                        }
                        Else {
                            Write-EventLog  -LogName PSUpdater -Source "PSUpdater_Client" -EntryType Information -EventId "5" -Message "Update installation complete and no reboot is required."
                    }
                }
        }
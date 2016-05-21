[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null

$WSUSserver = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()

Function Calculate-WeekNo($Date) {
        $script:Month = Get-Date $Date -Format "MM"
        $script:WeekNo = 1
        Do {
            If ($(Get-Date (($Date).AddDays(-7)) -Format "MM") -eq $script:Month) {
                $script:WeekNo++
                }
            $Date = $Date.AddDays(-7)
            }
            While ( $(Get-Date (($Date).AddDays(-7)) -Format "MM") -eq $script:Month )
        }

Calculate-WeekNo $(Get-Date)

If ($script:WeekNo -gt 4) {
    Send-MailMessage -To "to@domain" -From "wsus@domain.com" -SmtpServer "smtp" -Subject "WSUS automatic patch approval" -BodyAsHtml "<p>FYI: since this day does not fall in the first 4 instances of the day in the month, no updates will be automatically approved today.</p>"
    Exit 1
    }
    

$MoratoriumURI = "http://sharepoint/sites/site/Patch%20Approvals/moratorium.csv"
Invoke-WebRequest -Uri $MoratoriumURI -OutVariable Moratorium -UseDefaultCredentials | Out-Null
$Moratorium = $Moratorium | ConvertFrom-Csv

If (!($Moratorium)) {
    Send-MailMessage -To "to@domain" -From "wsus@domain.com" -SmtpServer "smtp" -Subject "WSUS automatic patch approval" -BodyAsHtml "<p>FYI: script failed as no moratorium file was found at the expected location.</p>"
    Exit 1
    }
    Else {
        If ($Moratorium.Year -notcontains $(Get-Date -Format "yyyy")) {
            Send-MailMessage -To "to@domain" -From "wsus@domain.com" -SmtpServer "smtp" -Subject "WSUS automatic patch approval" -BodyAsHtml "<p>FYI: script failed to run as there are no moratorium dates set up for this year.</p>"
            Exit 1
            }
        }

$InMoratorium = $False
Foreach ($Day in $Moratorium) {
    If ( $(Get-Date "$($Day.Month)/$($Day.Day)/$($day.Year)" -Format "MM/dd/yyyy") -eq $(Get-Date -Format "MM/dd/yyyy") ) {
        Send-MailMessage -To "to@domain" -From "wsus@domain.com" -SmtpServer "smtp" -Subject "WSUS automatic patch approval" -BodyAsHtml "<p>FYI: since this day is marked as under moratorium, no updates will be deadlined today. You may need to manually install these updates later.</p>"
        $InMoratorium = $True
        }
    }

Try {
    $SPUri = "http://sharepoint/sites/site/Patch%20Approvals/$(Get-Date -Format `"yyyy`")%20-%20$(Get-Date -Format `"MMMM`")/PROD_New_Approvals_approved.csv"
    Invoke-WebRequest -Uri $SPUri -OutVariable PRODApprovals -UseDefaultCredentials | Out-Null
    }
    Catch {
         $SPUri = "http://sharepoint/sites/site/Patch%20Approvals/$(Get-Date $(Get-Date).AddMonths(-1) -Format `"yyyy`")%20-%20$(Get-Date $(Get-Date).AddMonths(-1) -Format `"MMMM`")/PROD_New_Approvals_approved.csv"
         Invoke-WebRequest -Uri $SPUri -OutVariable PRODApprovals -UseDefaultCredentials | Out-Null
         }

Try {
    $PRODApprovals = $PRODApprovals | Convertfrom-CSV
    }
    Catch {
        Send-MailMessage -To "to@domain" -From "wsus@domain.com" -SmtpServer "smtp" -Subject "WSUS automatic patch approval" -BodyAsHtml "<p>FYI: there are no approvals on sharepoint to process.</p>"
        Exit 1
        }

$InstallAction = [Microsoft.UpdateServices.Administration.UpdateApprovalAction]"Install"

$WSUSGroup = $WSUSServer.GetComputerTargetGroups() | Where {$_.Name -like "$($Script:weekno)*$(Get-Date -Format "dddd")*"}
$UnmanagedGroups = @()
$UnmanagedGroups += $($WSUSServer.GetComputerTargetGroups() | Where {$_.Name -like "Patched By Owner"}), $($WSUSServer.GetComputerTargetGroups() | Where {$_.Name -like "Unassigned Computers"}), $($WSUSServer.GetComputerTargetGroups() | Where {$_.Name -like "Exceptions"})

If (($(Get-Date -Format "dddd") -like "Monday") -or ($(Get-Date -Format "dddd") -like "Tuesday") ) {
    Foreach($update in $PRODApprovals) {
        $AlreadyApproved = $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).GetUpdateApprovals() | Where {$_.Action -eq "Install" } | Select ComputerTargetGroupId
        If ($AlreadyApproved.ComputerTargetGroupId -contains $WSUSGroup.Id.Guid) {
                # Do nothing, already approved
                }
                Else {
                    If ($($WSUSserver.GetUpdate([guid]$Update.UpdateID)).RequiresLicenseAgreementAcceptance) { $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).AcceptLicenseAgreement() | Out-Null }
                    $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).Approve($InstallAction,$WSUSGroup) | Out-Null
                    }
        Foreach ($UnmanagedGroup in $UnmanagedGroups) {
                $AlreadyApproved = $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).GetUpdateApprovals() | Where {$_.Action -eq "Install" } | Select ComputerTargetGroupId
                If ($AlreadyApproved.ComputerTargetGroupId -contains $UnmanagedGroup.Id.Guid) {
                        # Do nothing, already approved
                        }
                        Else {
                            If ($($WSUSserver.GetUpdate([guid]$Update.UpdateID)).RequiresLicenseAgreementAcceptance) { $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).AcceptLicenseAgreement() | Out-Null }
                            $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).Approve($InstallAction,$UnmanagedGroup) | Out-Null
                            }
                    }
            }
    }
    ElseIf (($(Get-Date -Format "dddd") -like "Wednesday") -or ($(Get-Date -Format "dddd") -like "Thursday") ) {
        Foreach($update in $PRODApprovals) {
            $AlreadyApproved = $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).GetUpdateApprovals() | Where {$_.Action -eq "Install" } | Select ComputerTargetGroupId
            If ($AlreadyApproved.ComputerTargetGroupId -contains $WSUSGroup.Id.Guid) {
                    # Do nothing, already approved
                    }
                    Else {
                        If ($($WSUSserver.GetUpdate([guid]$Update.UpdateID)).RequiresLicenseAgreementAcceptance) { $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).AcceptLicenseAgreement() | Out-Null }
                        If ((Get-Date).IsDaylightSavingTime() -eq $True) {
                            If ($InMoratorium -ne $True) {
                                $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).Approve($InstallAction,$WSUSGroup,$((Get-Date "0:30").AddDays(1)).AddHours(-1)) | Out-Null
                                }
                                Else {
                                    $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).Approve($InstallAction,$WSUSGroup) | Out-Null
                                    }
                            }
                            Else {
                                If ($InMoratorium -ne $True) {
                                    $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).Approve($InstallAction,$WSUSGroup,$((Get-Date "0:30").AddDays(1))) | Out-Null
                                    }
                                Else {
                                    $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).Approve($InstallAction,$WSUSGroup) | Out-Null
                                    }
                                }
                        }
            Foreach ($UnmanagedGroup in $UnmanagedGroups) {
                $AlreadyApproved = $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).GetUpdateApprovals() | Where {$_.Action -eq "Install" } | Select ComputerTargetGroupId
                If ($AlreadyApproved.ComputerTargetGroupId -contains $UnmanagedGroup.Id.Guid) {
                        # Do nothing, already approved
                        }
                        Else {
                            If ($($WSUSserver.GetUpdate([guid]$Update.UpdateID)).RequiresLicenseAgreementAcceptance) { $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).AcceptLicenseAgreement() | Out-Null }
                            $($WSUSserver.GetUpdate([guid]$Update.UpdateID)).Approve($InstallAction,$UnmanagedGroup) | Out-Null
                            }
                    }
                }
        }

If ($InMoratorium -ne $True) {
    Start-Process "schtasks.exe" "/RUN /TN:`"Domain\Notify-PatchingAppOwners`""
    }
    Else {
        # Do nothing
        }
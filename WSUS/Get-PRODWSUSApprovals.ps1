Param(
    [switch]$IgnoreDate
    )

   $TuesdayDate = (Get-Date).AddDays(-10)
    $Dayvalue = $TuesdayDate.DayOfWeek.value__ + 1
    $DayofWeek = $TuesdayDate.DayOfWeek
    $Daynum = Get-Date $TuesdayDate -Format "dd"
    $script:Month = Get-Date $TuesdayDate -Format "MM"

    If (!($IgnoreDate.IsPresent)) {
        If ($DayofWeek -ne "Tuesday") {
            Exit 0
            }
    }

    $script:WeekNo = 1

    Function Calculate-WeekNo($Date) {
        Do {
            If ($(Get-Date (($Date).AddDays(-7)) -Format "MM") -eq $script:Month) {
                $script:WeekNo++
                }
            $Date = $Date.AddDays(-7)
            }
            While ( $(Get-Date (($Date).AddDays(-7)) -Format "MM") -eq $script:Month )
        }

    Calculate-WeekNo $TuesdayDate

    If (!($IgnoreDate.IsPresent)) {
        If ($Script:WeekNo -ne 2) {
            Exit 0
            }
        }

$SPUri = "http://sharepoint/sites/site/Patch%20Approvals/$(Get-Date $TuesdayDate -Format `"yyyy`")%20-%20$(Get-Date $TuesdayDate -Format `"MMMM`")/Lab_Approved.csv"
Invoke-WebRequest -Uri $SPUri -OutVariable LabApproved -UseDefaultCredentials | Out-Null
$LabApproved = $LabApproved | Convertfrom-CSV

[reflection.assembly]::LoadWithPartialName("Microsoft.UpdateServices.Administration") | Out-Null

$WSUSserver = [Microsoft.UpdateServices.Administration.AdminProxy]::GetUpdateServer()

$UpdateScope = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$UpdateScope.ApprovedStates = "LatestRevisionApproved"

$CurrentPRODApproved = $WSUSserver.GetUpdates($UpdateScope)

$UpdatesToApprove = New-Object Microsoft.UpdateServices.Administration.UpdateCollection

$AllComputers = New-Object Microsoft.UpdateServices.Administration.ComputerTargetScope
$AllComputers.IncludeDownstreamComputerTargets = $True

Foreach ($Update in $LabApproved) {
    $UpdateObj = $WSUSserver.GetUpdate([guid]$Update.ID)
    If ($CurrentPRODApproved -notcontains $UpdateObj) {
        $SummaryObj = $UpdateObj.GetSummary($AllComputers)
        If (($UpdateObj.IsDeclined -ne $True) -and ($SummaryObj.NotInstalledCount -ne 0)) {
            $UpdatesToApprove.Add($UpdateObj) | Out-Null
            }
        }
    $UpdateObj = $null
    $SummaryObj = $null
    }

$AwaitingApproval = New-Object Microsoft.UpdateServices.Administration.UpdateScope
$AwaitingApproval.ApprovedStates = "NotApproved"
$UpdatesinWaiting = $WSUSServer.GetUpdates($AwaitingApproval)
$OtherUpdates = New-Object Microsoft.UpdateServices.Administration.UpdateCollection

Foreach ($Update in $UpdatesinWaiting) {
    $UpdateObj = $WSUSserver.GetUpdate($Update.ID)
    If ($UpdatesToApprove -notcontains $UpdateObj) {
        $SummaryObj = $UpdateObj.GetSummary($AllComputers)
        If (($UpdateObj.IsDeclined -ne $True) -and ($SummaryObj.NotInstalledCount -ne 0)) {
            $OtherUpdates.Add($UpdateObj) | Out-Null
            }
        }
    }

$UpdatesToApprove | Select Title,@{"Name"="UpdateID";"Expression"={$_.ID.UpdateID} } | Export-CSV -NoTypeInformation "$($Env:TEMP)\PROD_New_Approvals.csv" -Force
$UpdatesToApprove | Select Title,@{"Name"="UpdateID";"Expression"={$_.ID.UpdateID} } | Export-CSV -NoTypeInformation "$($Env:TEMP)\PROD_New_Approvals_approved.csv" -Force

$EmailBody = "<style>td { padding-left: 5px; padding-right: 5px }</style><h3>$($UpdatesToApprove.Count) updates to be approved for $(Get-Date $TuesdayDate -Format "MMMM") (LAB tested)</h3><table style=`"background:#A7BFDE;border: 1px solid white;color:black;border-collapse:collapse;font-family:calibri;`"><tr style=`"background:#4F81BD;color:white`"><td style=`"border: 1px solid white;border-bottom: 2px`">Update Name</td><td style=`"border: 1px solid white;border-bottom: 2px`">UpdateID</td></tr>"
Foreach ($Update in $UpdatesToApprove) {
    $EmailBody = "$($EmailBody)<tr><td style=`"border: 1px solid white`">$($Update.Title)</td><td style=`"border: 1px solid white`">$($Update.ID.UpdateID)</td></tr>"
    }
$EmailBody = "$($EmailBody)</table>"
$EmailBody = "$($EmailBody)<h3>$($OtherUpdates.Count) other updates awaiting approval (potentially untested)</h3><table style=`"background:#A7BFDE;border: 1px solid white;color:black;border-collapse:collapse;font-family:calibri;`"><tr style=`"background:#4F81BD;color:white`"><td style=`"border: 1px solid white;border-bottom: 2px`">Update Name</td><td style=`"border: 1px solid white;border-bottom: 2px`">UpdateID</td></tr>"
Foreach ($Update in $OtherUpdates) {
    $EmailBody = "$($EmailBody)<tr><td style=`"border: 1px solid white`">$($Update.Title)</td><td style=`"border: 1px solid white`">$($Update.ID.UpdateID)</td></tr>"
    }
$EmailBody = "$($EmailBody)</table>"

Send-MailMessage -To "internalsysadmins@intrado.com" -From "LMV08-WSUS01@intrado.com" -Subject "$(Get-Date $TuesdayDate -Format `"MMMM`") $(Get-Date $TuesdayDate -Format `"yyyy`") WSUS Approvals" -SmtpServer "mail.intrado.com" -BodyAsHtml $($EmailBody) -Attachments "$($Env:TEMP)\PROD_New_Approvals_approved.csv"

Send-MailMessage -To "doclibrary@sharepoint" -From "wsus@domain" -Subject "$(Get-Date $TuesdayDate -Format `"yyyy`") - $(Get-Date $TuesdayDate -Format `"MMMM`")" -Attachments "$($Env:TEMP)\PROD_New_Approvals.csv" -SmtpServer smtp
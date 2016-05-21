[CmdletBinding()]
    Param(
        $BasePath="$($env:userprofile)\desktop\",
        [switch]$SendMail
        )

$ScriptPath = split-path -parent $MyInvocation.MyCommand.Definition

$Complianceobj = & "$($ScriptPath)\WSUS_compliance.ps1"

$CompliantCSV = "$($BasePath)\$(Get-Date -Format "MM-dd-yyyy")-PRODUCTION60DayCompliant.csv"
$NonCompliantCSV = "$($BasePath)\$(Get-Date -Format "MM-dd-yyyy")-PRODUCTION60DayNonCompliant.csv"
$OverallCSV = "$($BasePath)\$(Get-Date -Format "MM-dd-yyyy")-PRODUCTIONOverall.csv"

$Complianceobj.Compliant | Get-Member | Where {$_.MemberType -eq "NoteProperty"} | Foreach-Object { $prop = $_.Name ; New-Object PSCustomObject -Property @{"Name"=$Complianceobj.Compliant.$prop.Name;"LastSyncTime"=$Complianceobj.Compliant.$prop.LastSyncTime } | Export-CSV -NoTypeInformation -Path $CompliantCSV -Append }
$Complianceobj.NonCompliant | Get-Member | Where {$_.MemberType -eq "NoteProperty"} | Foreach-Object { $prop = $_.Name ; New-Object PSCustomObject -Property @{"Name"=$Complianceobj.NonCompliant.$prop.Name;"LastSynctime"=$Complianceobj.NonCompliant.$prop.LastSyncTime;"Updates"=$Complianceobj.NonCompliant.$prop.Updates.Count;"Responsible Group"=$Complianceobj.NonCompliant.$prop.ResponsibleGroup } | Export-CSV -NoTypeInformation -Path $NonCompliantCSV -Append }
$Complianceobj.Overall | Get-Member | Where {$_.MemberType -eq "NoteProperty"} | Foreach-Object { $prop = $_.Name ; New-Object PSCustomObject -Property @{"Name"=$Complianceobj.Overall.$prop.Name;"LastSyncTime"=$Complianceobj.Overall.$prop.LastSyncTime;"Responsible Group"=$Complianceobj.Overall.$prop.ResponsibleGroup;"Updates"=$Complianceobj.Overall.$prop.Updates } | Export-CSV -NoTypeInformation -Path $OverallCSV -Append }

$Complianceobj

If ($SendMail.IsPresent) {
    Send-MailMessage -To "doclibrary@domain" -From "wsus@domain" -Subject "PROD WSUS Compliance Reports" -Attachments $CompliantCSV,$NonCompliantCSV,$OverallCSV -SmtpServer $smtpserver

    Function Get-OwnerEmail($Owner) {
        Switch ($Owner) {
            "Group 1" { "group1@domain.com" }
            }
        }
        $ToEmail = Import-CSV $NonCompliantCSV | Select "Responsible Group" -Unique
        Foreach ($OwnerGroup in $ToEmail) {
            $Body = "<p>Please see below for a list of servers considered to be out-of-compliance as of the current date. Released patches must be installed within 60 days in order to maintain compliance, and these must be remediated if a formal exception is not on file.<br/><br/>Please let us know if you have any questions, or if you are not the custodian patching any or all of these systems. Thank you.</p><br/>"
            $Body = "$($Body)<table style=`"background:#A7BFDE;border: 1px solid white;color:black;border-collapse:collapse;font-family:calibri;`"><strong><tr style=`"background:#4F81BD;color:white`"><td style=`"border: 1px solid white;border-bottom: 2px;padding-left:3px;padding-right:3px`">Server Name</td><td style=`"border: 1px solid white;border-bottom:2px;padding-left:3px;padding-right:3px`">Patches > 60 Days</td><td style=`"border: 1px solid white;border-bottom: 2px;padding-left:3px;padding-right:3px`">LastSyncTime</td></tr></strong>"
            Foreach ($line in $(Import-CSV $NonCompliantCSV | Where {$_."Responsible Group" -eq $($OwnerGroup."Responsible Group")})) {
                $Body = "$($Body)<tr><td style=`"background:#4F81BD;color:white;border: 1px solid white;border-right: 2px;padding-left:3px;padding-right:3px`">$($line.Name)</td><td style=`"border: 1px solid white;text-align:right;padding-left:3px;padding-right:3px`">$($line.Updates)</td><td style=`"border: 1px solid white;padding-left:3px;padding-right:3px`">$($line.LastSyncTime)</td></tr>"
                }
            $Body = "$($Body)</table>"
            Send-MailMessage -To "$(Get-OwnerEmail $($OwnerGroup."Responsible Group"))" -From "to@domain" -Subject "Patching compliance: $($OwnerGroup."Responsible Group")" -BodyAsHtml $Body -SmtpServer $smtpserver
            $Body = $null
            }
    }
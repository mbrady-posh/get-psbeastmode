Try {
    $URI = "http://sharepoint/sites/site/_vti_bin/lists.asmx?WSDL"
    $service = New-WebServiceProxy -Uri $uri  -Namespace SpWs  -UseDefaultCredential
    $List = "Patching Inventory App Owners and Schedules"
    $xmlDoc = new-object System.Xml.XmlDocument
    $query = [xml]"<Query />"
    $viewFields = [xml]"<ViewFields/>"
    $queryOptions = [xml]"<QueryOptions />"
    $rowLimit = "1000"

    If ($Service -ne $null) {
        $listobj = $service.GetListItems($list, "", $query, $viewFields, $rowLimit, $queryOptions, "")
        }
        Else {
            Throw  "Service is dead"
            }

    $CurrentDate = Get-Date

    $Dayvalue = $CurrentDate.DayOfWeek.value__ + 1
    $DayofWeek = $CurrentDate.DayOfWeek
    $Daynum = Get-Date $CurrentDate -Format "dd"
    $script:Month = Get-Date $CurrentDate -Format "MM"

    If ( ($DayofWeek -eq "Saturday") -or ($DayofWeek -eq "Sunday") -or ($DayofWeek -eq "Friday")) {
        Exit 0
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

    Calculate-WeekNo $CurrentDate

    $serverlist = $listobj.data.row | Where {$_.ows_Future_x0020_Tier_x0020_Grouping -like "$($script:WeekNo)*$($DayofWeek)*" }| Select ows_Title,ows_Future_x0020_Tier_x0020_Grouping,ows_App_x0020_Owner,ows_Notes

    $Subject = "Change notification - Internal Systems patching $(Get-Date -Format "MM-dd-yyyy")"
    $SMTP = "smtp"
    $Sender = "from@domain"
    <# $Recipient = Switch ($script:WeekNo) {
                                1 { "patch-first-$($DayofWeek)@intrado.com" }
                                2 { "patch-second-$($DayofWeek)@intrado.com" }
                                3 { "patch-third-$($DayofWeek)@intrado.com" }
                                4 { "patch-fourth-$($DayofWeek)@intrado.com" }
                                default { $null }
                                }

    If ($Recipient -eq $null) {
        Throw "No patch schedule for today."
        Exit 1
        } #>

    $Recipient = "internalsysadmins@intrado.com"

    $Body = "<style>td { padding-left: 5px; padding-right: 5px }</style>Please see the list below of servers to be patched (and rebooted if necessary) tonight. If you have any questions or concerns, please let us know. Thank you.<br/><br/><table style=`"background:#A7BFDE;border: 1px solid white;color:black;border-collapse:collapse;font-family:calibri;`"><strong><tr style=`"background:#4F81BD;color:white`"><td style=`"border: 1px solid white;border-bottom: 2px`">Server Name</td><td style=`"border: 1px solid white;border-bottom:2px`">Patch Schedule</td><td style=`"border: 1px solid white;border-bottom: 2px`">App Owner</td><td style=`"border: 1px solid white;border-bottom: 2px`">Notes</td></tr></strong>"

    Foreach ($Server in $serverlist) {
        $Body = $Body + "<tr><td style=`"background:#4F81BD;color:white;border: 1px solid white;border-right: 2px`">$($server.ows_Title)</td><td style=`"border: 1px solid white`">$($Server.ows_Future_x0020_Tier_x0020_Grouping)</td><td style=`"border: 1px solid white`">$($Server.ows_App_x0020_Owner)</td><td style=`"border: 1px solid white`">$($Server.ows_Notes)</td></tr>"
        }

    $Body = $Body + "</table>"

    Send-MailMessage -From $Sender -SmtpServer $SMTP -To $Recipient -BodyAsHtml $Body -Subject $Subject -Priority High
    }
    Catch {
        Send-MailMessage -From $Sender -To $To -Subject "Patch Auto-Notification Failure" -BodyAsHtml "See below for error details.<br/><br/>$($error[0])" -SmtpServer $SMTP
        }


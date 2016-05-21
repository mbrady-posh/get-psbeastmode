Param(
    [Parameter(Mandatory=$True)][string]$CSVPath,
    [Parameter(Mandatory=$True)][string]$UserListPath,
    [Parameter(Mandatory=$True)][string]$FirstPayDay,
    [string]$APIPath = "C:\Program Files\Microsoft\Exchange\Web Services\1.2\Microsoft.Exchange.WebServices.dll",
    [string]$ExchangeVersion = "Exchange2007_SP1",
    [string]$ServerFQDN = "exchange.domain.com"
    )

Add-Type -Path $APIPath

If ( (!(Test-Path $CSVPath)) -or (!(Test-Path $UserListPath))) {
    Throw "One or more parameters were invalid, please check them and try again."
    Exit 1
    }

$Appointments = Import-CSV $CSVPath
$UserList = Get-Content $UserListPath

$service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService -ArgumentList ([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::$ExchangeVersion)
$service.Url = [system.URI]"https://$($ServerFQDN)/ews/exchange.asmx"

New-Item -ItemType File -Path "$($env:userprofile)\desktop\appointmentbackout.csv" -Force | Out-Null
"User,ID" | Add-Content "$($env:userprofile)\desktop\appointmentbackout.csv" -Force
Foreach ($Email in $UserList) {
    $service.ImpersonatedUserId = New-Object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId -ArgumentList ([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress,"$($Email)")
    Foreach ($Appt in $Appointments) {
        $apptobj = New-Object Microsoft.Exchange.WebServices.Data.Appointment -ArgumentList $service -Property @{"Subject" = "$($Appt.Subject)";"Body" = "$($Appt.Body)";"Start" = "$(Get-Date ($Appt.Start))";"End" = "$(Get-Date ($Appt.End))";"LegacyFreeBusyStatus" = "Free"; "IsAllDayEvent" = $true ; "IsReminderSet"=$False ;}
        $apptobj.Save([Microsoft.Exchange.WebServices.Data.SendInvitationsMode]::SendToAllAndSaveCopy)
        "$($Email),$($apptobj.Id)" | Add-Content "$($env:userprofile)\desktop\appointmentbackout.csv" -Force
        $apptobj = $null
        }

    $PayDay = New-Object Microsoft.Exchange.WebServices.Data.Appointment -ArgumentList $service -Property @{"Subject" = "jour de paie/pay day (Québec & U.S.)"; "Body" = ""; "LegacyFreeBusyStatus" = "Free"; "IsAllDayEvent" = $True ; "IsReminderSet" = $False }
    $Friday = [Microsoft.Exchange.WebServices.Data.DayOfTheWeek]::Friday
    $PayDay.Recurrence = New-Object Microsoft.Exchange.WebServices.Data.Recurrence+WeeklyPattern($(Get-Date "$($FirstPayDay)"),2,$Friday)
    $PayDay.Recurrence.EndDate = "12/31/$((Get-Date $FirstPayDay).Year)"
    $PayDay.Save([Microsoft.Exchange.WebServices.Data.SendInvitationsMode]::SendToAllAndSaveCopy)
    "$($Email),$($PayDay.Id)" | Add-Content "$($env:userprofile)\desktop\appointmentbackout.csv" -Force
    $payDay = $null
    }
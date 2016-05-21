Param(
    [Parameter(Mandatory=$True)][string]$AppointmentIDCSV,
    [string]$APIPath = "C:\Program Files\Microsoft\Exchange\Web Services\1.2\Microsoft.Exchange.WebServices.dll",
    [string]$ExchangeVersion = "Exchange2007_SP1",
    [string]$ServerFQDN = "exchange.domain.com"
    )

Add-Type -Path $APIPath

If (!(Test-Path $AppointmentIDCSV)) {
    Throw "One or more parameters were invalid, please check them and try again."
    Exit 1
    }

$AppointmentIDs = Import-CSV $AppointmentIDCSV

$service = New-Object Microsoft.Exchange.WebServices.Data.ExchangeService -ArgumentList ([Microsoft.Exchange.WebServices.Data.ExchangeVersion]::$ExchangeVersion)
$service.Url = [system.URI]"https://$($ServerFQDN)/ews/exchange.asmx"

Foreach ($AppointmentID in $AppointmentIDs) {
    $service.ImpersonatedUserId = New-Object Microsoft.Exchange.WebServices.Data.ImpersonatedUserId -ArgumentList ([Microsoft.Exchange.WebServices.Data.ConnectingIdType]::SmtpAddress,"$($AppointmentID.User)")
    $ApptToDelete = [Microsoft.Exchange.WebServices.Data.Appointment]::Bind($Service, $AppointmentID.ID)
    $ApptToDelete.Delete([Microsoft.Exchange.WebServices.Data.DeleteMode]"HardDelete")
    $ApptToDelete = $null
    }
<#

    .SYNOPSIS

    This script gathers information about malware infections from WMI (for System Center Endpoint Protection/Windows Defender) and sends it in an HTML email.

    .DESCRIPTION

    This script is used in lieu of utilizing System Center Configuration Manager on servers. The Endpoint Protection client data is accessible via WMI but there is no built-in way to alert admins or report to a central location, so this script fills that need by utilizing email. Can be paired with a Group Policy-set Scheduled Task to great effect. Email Address and an SMTP server must be specified in the script. Written by Michael Brady.

    .EXAMPLE

    .\Send-SCEPAlert.ps1

    If active infections are found on the client, an email will be sent to the email address given in the script with details.

#>

$EmailAddress = ""
$Subject = "Malware Alert for $env:ComputerName"
$EmailServer = ""

$SendMail = 0

$EmailBody = ""
$SCEPStatus = Get-WMiobject -Namespace Root\Microsoft\SecurityClient -Class AntiMalwareInfectionStatus
If ($SCEPStatus.ComputerStatus -eq 2) {
    $SendMail = 1
    Foreach ($Threat in $SCEPStatus.RecentlyCleanedDetections) {
        $EmailBody = $Emailbody + "<table><tr><td>Process</td><td>$($Threat.Process)</td></tr><tr><td>Files</td><td>$($Threat.Resources)</td></tr><tr><td>DetectionTime</td><td>$(Get-Date $Threat.DetectionTime -Format g)</td></tr><tr><td>Threat Name</td><td>$($Threat.ThreatName)</td></tr><tr><td>User</td><td>$($Threat.User)</td></tr></table><br/><br/>"
        }
    Foreach ($Threat in $SCEPStatus.PendingActionDetections) {
        $EmailBody = $Emailbody + "<table><tr><td>Process</td><td>$($Threat.Process)</td></tr><tr><td>Files</td><td>$($Threat.Resources)</td></tr><tr><td>DetectionTime</td><td>$(Get-Date $Threat.DetectionTime -Format g)</td></tr><tr><td>Threat Name</td><td>$($Threat.ThreatName)</td></tr><tr><td>User</td><td>$($Threat.User)</td></tr></table><br/><br/>"
        }
    Foreach ($Threat in $SCEPStatus.CriticallyFailedDetections) {
        $EmailBody = $Emailbody + "<table><tr><td>Process</td><td>$($Threat.Process)</td></tr><tr><td>Files</td><td>$($Threat.Resources)</td></tr><tr><td>DetectionTime</td><td>$(Get-Date $Threat.DetectionTime -Format g)</td></tr><tr><td>Threat Name</td><td>$($Threat.ThreatName)</td></tr><tr><td>User</td><td>$($Threat.User)</td></tr></table><br/><br/>"
        }
    }

If ($SendMail -eq 1) {
    Send-MailMessage -To "$EmailAddress" -From $EmailAddress -Subject $Subject -BodyAsHtml "<html><body><p>$EmailBody</p></body></html>" -SmtpServer $EmailServer
    }
$EmailBody = ""
$SendMail = 0